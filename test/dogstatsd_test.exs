defmodule DogStatsdTest do
  use ExUnit.Case
  require DogStatsd

  setup do
    {:ok, dogstatsd} = DogStatsd.new("localhost", 1234)
    Process.register dogstatsd, :dogstatsd
    :ok
  end


  ##########
  # new
  ##########

  test "sets the host and port" do
    assert DogStatsd.host(:dogstatsd) == "localhost"
    assert DogStatsd.port(:dogstatsd) == 1234
  end

  test "defaults the host to 127.0.0.1, port to 8125, namespace to nil, and tags to []" do
    {:ok, statsd} = DogStatsd.new
    assert DogStatsd.host(statsd) == "127.0.0.1"
    assert DogStatsd.port(statsd) == 8125
    assert DogStatsd.namespace(statsd) == nil
    assert DogStatsd.tags(statsd) == []
  end

  test "should be able to set host, port, namespace, and global tags" do
    {:ok, statsd} = DogStatsd.new "1.3.3.7", 8126, %{:tags => ["global"], :namespace => "space"}
    assert DogStatsd.host(statsd) == "1.3.3.7"
    assert DogStatsd.port(statsd) == 8126
    assert DogStatsd.namespace(statsd) == "space"
    assert DogStatsd.tags(statsd) == ["global"]
  end

end
