Application.ensure_all_started([:inets, :ssl])

archive_path = ~c'_build/kubernetes.tgz'
out_path = "build/resource_path_mapping.ex"
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

  for main_resource <-
        Enum.reject(api_resource_list["resources"], &String.contains?(&1["name"], "/")) do
    prefix = "#{main_resource["name"]}/"

    subresources =
      for %{"name" => <<^prefix::binary, subresource::binary>>} = subresource_definition
          when subresource not in ["exec", "proxy", "attach", "log", "portforward"] <-
            api_resource_list["resources"] do
        subresource_definition
        |> Map.put("subresource", subresource)
        |> Map.put("name", main_resource["name"])
      end

    [main_resource | subresources]
  end
  |> List.flatten()
end

api = extract_file.("api.json")

core_apis =
  for version <- api["versions"],
      api_resource <- format_api_resource_list.("api__#{version}.json"),
      into: %{} do
    if api_resource["namespaced"] do
      {"#{version}/#{api_resource["kind"]}/#{api_resource["subresource"]}",
       "api/#{version}/namespaces/:namespace/#{api_resource["name"]}/:name/#{api_resource["subresource"]}"}
    else
      {"#{version}/#{api_resource["kind"]}/#{api_resource["subresource"]}/#{api_resource["subresource"]}",
       "api/#{version}/#{api_resource["name"]}/:name"}
    end
  end

api_groups = extract_file.("apis.json")

extended_apis =
  for api_group <- api_groups["groups"],
      version <- api_group["versions"],
      api_resource <-
        format_api_resource_list.("apis__#{api_group["name"]}__#{version["version"]}.json"),
      into: %{} do
    if api_resource["namespaced"] do
      {"#{api_group["name"]}/#{version["version"]}/#{api_resource["kind"]}/#{api_resource["subresource"]}",
       "apis/#{api_group["name"]}/#{version["version"]}/namespaces/:namespace/#{api_resource["name"]}/:name/#{api_resource["subresource"]}"}
    else
      {"#{api_group["name"]}/#{version["version"]}/#{api_resource["kind"]}/#{api_resource["subresource"]}",
       "apis/#{api_group["name"]}/#{version["version"]}/#{api_resource["name"]}/:name/#{api_resource["subresource"]}"}
    end
  end

discovery = Map.merge(core_apis, extended_apis)
File.write!(out_path, inspect(discovery, printable_limit: :infinity, limit: :infinity))
