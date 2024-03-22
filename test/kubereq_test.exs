defmodule KubereqTest do
  use ExUnit.Case
  doctest Kubereq

  test "greets the world" do
    assert Kubereq.hello() == :world
  end
end
