defmodule DogStatsdTest do
  use ExUnit.Case
  require DogStatsd

  setup do
    {:ok, dogstatsd} = DogStatsd.new("localhost", 1234)
    Process.register dogstatsd, :dogstatsd

    {:ok, listener} = :gen_udp.open(1234)

    on_exit fn ->
      :gen_udp.close(listener)
    end

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


  ##########
  # writers
  ##########

  test "sets host, port, namespace, and global tags" do
    DogStatsd.host(:dogstatsd, "1.2.3.4")
    DogStatsd.port(:dogstatsd, 5678)
    DogStatsd.namespace(:dogstatsd, "n4m35p4c3")
    DogStatsd.tags(:dogstatsd, "t4g5")

    assert DogStatsd.host(:dogstatsd) == "1.2.3.4"
    assert DogStatsd.port(:dogstatsd) == 5678
    assert DogStatsd.namespace(:dogstatsd) == "n4m35p4c3"
    assert DogStatsd.tags(:dogstatsd) == "t4g5"
  end

  test "does not resolve hostnames to IPs" do
    DogStatsd.host(:dogstatsd, "localhost")
    assert DogStatsd.host(:dogstatsd) == "localhost"
  end

  test "sets nil host to default" do
    DogStatsd.host(:dogstatsd, nil)
    assert DogStatsd.host(:dogstatsd) == "127.0.0.1"
  end

  test "sets nil port to default" do
    DogStatsd.port(:dogstatsd, nil)
    assert DogStatsd.port(:dogstatsd) == 8125
  end

  test "sets prefix to nil when namespace is set to nil" do
    DogStatsd.namespace(:dogstatsd, nil)
    assert DogStatsd.namespace(:dogstatsd) == nil
    assert DogStatsd.prefix(:dogstatsd) == nil
  end

  test "sets nil tags to default" do
    DogStatsd.tags(:dogstatsd, nil)
    assert DogStatsd.tags(:dogstatsd) == []
  end


  ###########
  # increment
  ###########

  test "formats the increment message according to the statsd spec" do
    DogStatsd.increment(:dogstatsd, "foobar")
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:1|c'}
  end

  test "with a sample rate should format the increment message according to the statsd spec" do
    DogStatsd.increment(:dogstatsd, "foobar", %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:1|c|@1.0'}
  end


  ###########
  # decrement
  ###########

  test "formats the decrement message according to the statsd spec" do
    DogStatsd.decrement(:dogstatsd, "foobar")
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:-1|c'}
  end

  test "with a sample rate should format the decrement message according to the statsd spec" do
    DogStatsd.decrement(:dogstatsd, "foobar", %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:-1|c|@1.0'}
  end


  ###########
  # gauge
  ###########

  test "should send a message with a 'g' type" do
    DogStatsd.gauge(:dogstatsd, "begrutten-suffusion", 536)
    assert_receive {:udp, _port, _from_ip, _from_port, 'begrutten-suffusion:536|g'}
    DogStatsd.gauge(:dogstatsd, "begrutten-suffusion", -107.3)
    assert_receive {:udp, _port, _from_ip, _from_port, 'begrutten-suffusion:-107.3|g'}
  end

  test "with a sample rate should format the guage message according to the statsd spec" do
    DogStatsd.gauge(:dogstatsd, "begrutten-suffusion", 536, %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'begrutten-suffusion:536|g|@1.0'}
  end


  ###########
  # histogram
  ###########

  test "should send a message with a 'h' type" do
    DogStatsd.histogram(:dogstatsd, "ohmy", 536)
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:536|h'}
    DogStatsd.histogram(:dogstatsd, "ohmy", -107.3)
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:-107.3|h'}
  end

  test "with a sample rate should format the histogram message according to the statsd spec" do
    DogStatsd.histogram(:dogstatsd, "ohmy", 536, %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:536|h|@1.0'}
  end

end
