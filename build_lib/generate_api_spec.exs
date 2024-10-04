Application.ensure_all_started([:inets, :ssl])

archive_path = ~c'_build/kubernetes.tgz'
out_path = "lib/kubereq/discovery/resource_path_mapping.ex"
gh_token = System.fetch_env!("GITHUB_TOKEN")

to_string = fn
  string when is_binary(string) -> string
  charlist when is_list(charlist) -> List.to_string(charlist)
end

download = fn url, headers ->
  {:ok, {{_, _status, _}, _, response_body}} = :httpc.request(:get, {url, headers}, [], [])
  response_body
end

json_decode = fn str ->
  {body, :ok, ""} =
    str
    |> to_string.()
    |> :json.decode(:ok, %{null: nil})

  body
end

# download sources
headers = [
  {~c'Accept', ~c'application/vnd.github+json'},
  {~c'User-Agent', ~c'mruoss/kubereq'},
  {~c'Authorization', ~c'Bearer #{gh_token}'}
]

release =
  ~c'https://api.github.com/repos/kubernetes/kubernetes/releases/latest'
  |> download.(headers)
  |> json_decode.()

tag =
  ~c'https://api.github.com/repos/kubernetes/kubernetes/git/refs/tags/#{release["tag_name"]}'
  |> download.(headers)
  |> json_decode.()

archive_dir = "kubernetes-kubernetes-" <> String.slice(tag["object"]["sha"], 0, 7)

File.mkdir_p!(Path.dirname(archive_path))
if not File.exists?(archive_path) do
  {:ok, :saved_to_file} =
    :httpc.request(:get, {release["tarball_url"], headers}, [], stream: archive_path)
end

extract_file = fn file ->
  files = [Path.join([archive_dir, "api/discovery", file]) |> String.to_charlist()]

  {:ok, [{_, content}]} =
    :erl_tar.extract(archive_path, [:compressed, :memory, cwd: ~c'_build', files: files])

  json_decode.(content)
end

format_api_resource_list = fn api_resource_list_file ->
  api_resource_list = extract_file.(api_resource_list_file)
  Enum.reject(api_resource_list["resources"], &String.contains?(&1["name"], "/"))
end

api = extract_file.("api.json")

core_apis =
  for version <- api["versions"],
      api_resource <- format_api_resource_list.("api__#{version}.json") do
    path =
      if api_resource["namespaced"] do
        "api/#{version}/namespaces/:namespace/#{api_resource["name"]}/:name"
      else
        "api/#{version}/#{api_resource["name"]}/:name"
      end

    [
      {api_resource["kind"], path},
      {"#{version}/#{api_resource["kind"]}", path}
    ]
  end

api_groups = extract_file.("apis.json")

extended_apis =
  for api_group <- api_groups["groups"],
      version <- api_group["versions"],
      api_resource <-
        format_api_resource_list.("apis__#{api_group["name"]}__#{version["version"]}.json") do
    path =
      if api_resource["namespaced"] do
        "apis/#{api_group["name"]}/#{version["version"]}/namespaces/:namespace/#{api_resource["name"]}/:name"
      else
        "apis/#{api_group["name"]}/#{version["version"]}/#{api_resource["name"]}/:name"
      end

    [
      {"#{api_group["name"]}/#{version["version"]}/#{api_resource["kind"]}", path},
      {api_resource["kind"], path}
    ]
  end

discovery = List.flatten(core_apis ++ extended_apis) |> Map.new()

resource_path_mapping =
  quote do
    defmodule Kubereq.Discovery.ResourcePathMapping do
      @moduledoc false

      @spec lookup(key :: String.t()) :: String.t() | nil
      def lookup(key) do
        unquote(Macro.escape(discovery))[key]
      end
    end
  end

{:ok, out_file} = File.open(out_path, [:write])

# https://elixirforum.com/t/how-to-increase-printable-limit-from-macro-to-string/13613/5?u=mruoss
resource_path_mapping
|> Macro.to_string()
|> Code.format_string!()
|> then(&IO.write(out_file, &1))

IO.write(out_file, "\n")
File.close(out_file)
