defmodule DogStatsdTest do
  use ExUnit.Case
  require DogStatsd

  setup do
    {:ok, dogstatsd} = DogStatsd.new("localhost", 1234)
    Process.register(dogstatsd, :dogstatsd)

    {:ok, listener} = :gen_udp.open(1234)

    on_exit(fn ->
      :gen_udp.close(listener)
    end)

    :ok
  end

  ##########
  # new
  ##########

  test "sets the host and port" do
    assert DogStatsd.host(:dogstatsd) == "localhost"
    assert DogStatsd.port(:dogstatsd) == 1234
  end

  test "defaults the host to 127.0.0.1, port to 8125, namespace to nil, tags to [] and max buffer size to 50" do
    {:ok, statsd} = DogStatsd.new()
    assert DogStatsd.host(statsd) == "127.0.0.1"
    assert DogStatsd.port(statsd) == 8125
    assert DogStatsd.namespace(statsd) == nil
    assert DogStatsd.tags(statsd) == []
    assert DogStatsd.max_buffer_size(statsd) == 50
  end

  test "should be able to set host, port, namespace, global tags and max_buffer_size" do
    {:ok, statsd} =
      DogStatsd.new("1.3.3.7", 8126, %{
        :tags => ["global"],
        :namespace => "space",
        :max_buffer_size => 25
      })

    assert DogStatsd.host(statsd) == "1.3.3.7"
    assert DogStatsd.port(statsd) == 8126
    assert DogStatsd.namespace(statsd) == "space"
    assert DogStatsd.tags(statsd) == ["global"]
    assert DogStatsd.max_buffer_size(statsd) == 25
    assert DogStatsd.prefix(statsd) == "space."
  end

  ##########
  # writers
  ##########

  test "sets host, port, namespace, global tags and max_buffer_size" do
    DogStatsd.host(:dogstatsd, "1.2.3.4")
    DogStatsd.port(:dogstatsd, 5678)
    DogStatsd.namespace(:dogstatsd, "n4m35p4c3")
    DogStatsd.tags(:dogstatsd, "t4g5")
    DogStatsd.max_buffer_size(:dogstatsd, 25)

    assert DogStatsd.host(:dogstatsd) == "1.2.3.4"
    assert DogStatsd.port(:dogstatsd) == 5678
    assert DogStatsd.namespace(:dogstatsd) == "n4m35p4c3"
    assert DogStatsd.tags(:dogstatsd) == "t4g5"
    assert DogStatsd.max_buffer_size(:dogstatsd) == 25
    assert DogStatsd.prefix(:dogstatsd) == "n4m35p4c3."
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

  test "sets nil max_buffer_size to default" do
    DogStatsd.max_buffer_size(:dogstatsd, nil)
    assert DogStatsd.max_buffer_size(:dogstatsd) == 50
  end

  test "sets string port to integer" do
    DogStatsd.port(:dogstatsd, "5678")
    assert DogStatsd.port(:dogstatsd) == 5678
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

  test "should send a message with an 'h' type" do
    DogStatsd.histogram(:dogstatsd, "ohmy", 536)
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:536|h'}
    DogStatsd.histogram(:dogstatsd, "ohmy", -107.3)
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:-107.3|h'}
  end

  test "with a sample rate should format the histogram message according to the statsd spec" do
    DogStatsd.histogram(:dogstatsd, "ohmy", 536, %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'ohmy:536|h|@1.0'}
  end

  ###########
  # set
  ###########

  test "should send a message with an 's' type" do
    DogStatsd.set(:dogstatsd, "my.set", 536)
    assert_receive {:udp, _port, _from_ip, _from_port, 'my.set:536|s'}
  end

  ###########
  # timing
  ###########

  test "should send a message with an 'ms' type" do
    DogStatsd.timing(:dogstatsd, "foobar", 500)
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:500|ms'}
  end

  test "with a sample rate should format the timing message according to the statsd spec" do
    DogStatsd.timing(:dogstatsd, "foobar", 500, %{:sample_rate => 1.0})
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:500|ms|@1.0'}
  end

  ###########
  # time
  ###########

  test "formats the time message correctly and returns the value of the block" do
    return_value =
      DogStatsd.time :dogstatsd, "foobar" do
        :timer.sleep(1)
        "test"
      end

    assert return_value == "test"
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:1|ms'}
  end

  test "with a sample rate should format the time message according to the statsd spec" do
    return_value =
      DogStatsd.time :dogstatsd, "foobar", %{:sample_rate => 1.0} do
        :timer.sleep(1)
        "test"
      end

    assert return_value == "test"
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:1|ms|@1.0'}
  end

  ############
  # namespaces
  ############

  test "adds namespace to increment" do
    DogStatsd.namespace(:dogstatsd, "service")

    DogStatsd.increment(:dogstatsd, "foobar")

    assert_receive {:udp, _port, _from_ip, _from_port, 'service.foobar:1|c'}
  end

  test "adds namespace to decrement" do
    DogStatsd.namespace(:dogstatsd, "service")

    DogStatsd.decrement(:dogstatsd, "foobar")

    assert_receive {:udp, _port, _from_ip, _from_port, 'service.foobar:-1|c'}
  end

  test "adds namespace to timing" do
    DogStatsd.namespace(:dogstatsd, "service")

    DogStatsd.timing(:dogstatsd, "foobar", 500)

    assert_receive {:udp, _port, _from_ip, _from_port, 'service.foobar:500|ms'}
  end

  test "adds namespace to gauge" do
    DogStatsd.namespace(:dogstatsd, "service")

    DogStatsd.gauge(:dogstatsd, "foobar", 500)

    assert_receive {:udp, _port, _from_ip, _from_port, 'service.foobar:500|g'}
  end

  ############
  # stat names
  ############

  test "replaces statsd reserved chars in the stat name" do
    DogStatsd.increment(:dogstatsd, "ray@hostname.blah|blah.blah:blah")
    assert_receive {:udp, _port, _from_ip, _from_port, 'ray_hostname.blah_blah.blah_blah:1|c'}
  end

  ########
  # tags
  ########

  test "gauges support tags" do
    DogStatsd.gauge(:dogstatsd, "gauge", 1, %{tags: ["country:usa", "state:ny"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 'gauge:1|g|#country:usa,state:ny'}
  end

  test "counters support tags" do
    DogStatsd.increment(:dogstatsd, "c", %{tags: ["country:usa", "other"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:1|c|#country:usa,other'}

    DogStatsd.decrement(:dogstatsd, "c", %{tags: ["country:china"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:-1|c|#country:china'}

    DogStatsd.count(:dogstatsd, "c", 100, %{tags: ["country:finland"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:100|c|#country:finland'}
  end

  test "timing support tags" do
    DogStatsd.timing(:dogstatsd, "t", 200, %{tags: ["country:canada", "other"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 't:200|ms|#country:canada,other'}

    result =
      DogStatsd.time :dogstatsd, "foobar", %{:tags => ["123"]} do
        :timer.sleep(1)
        "test"
      end

    assert result == "test"
    assert_receive {:udp, _port, _from_ip, _from_port, 'foobar:1|ms|#123'}
  end

  test "global tags setter" do
    DogStatsd.tags(:dogstatsd, ["country:usa", "other"])
    DogStatsd.increment(:dogstatsd, "c")
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:1|c|#country:usa,other'}
  end

  test "global tags setter and regular tags" do
    DogStatsd.tags(:dogstatsd, ["country:usa", "other"])
    DogStatsd.increment(:dogstatsd, "c", %{tags: ["somethingelse"]})
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:1|c|#country:usa,other,somethingelse'}
  end

  test "nil global tags" do
    DogStatsd.tags(:dogstatsd, nil)
    DogStatsd.increment(:dogstatsd, "c")
    assert_receive {:udp, _port, _from_ip, _from_port, 'c:1|c'}
  end

  ##########
  # batched
  ##########

  test "allows sending single sample in one packet" do
    DogStatsd.batch(:dogstatsd, fn s ->
      s.increment(:dogstatsd, "mycounter")
    end)

    assert_receive {:udp, _port, _from_ip, _from_port, 'mycounter:1|c'}
  end

  test "allows sending multiple samples in one packet" do
    DogStatsd.batch(:dogstatsd, fn s ->
      s.increment(:dogstatsd, "mycounter")
      s.decrement(:dogstatsd, "myothercounter")
    end)

    assert_receive {:udp, _port, _from_ip, _from_port, 'mycounter:1|c\nmyothercounter:-1|c'}
  end

  test "defaults back to single metric packets after the block" do
    DogStatsd.batch(:dogstatsd, fn s ->
      s.gauge(:dogstatsd, "mygauge", 10)
      s.gauge(:dogstatsd, "myothergauge", 20)
    end)

    DogStatsd.increment(:dogstatsd, "mycounter")
    DogStatsd.increment(:dogstatsd, "myothercounter")

    assert_receive {:udp, _port, _from_ip, _from_port, 'mygauge:10|g\nmyothergauge:20|g'}
    assert_receive {:udp, _port, _from_ip, _from_port, 'mycounter:1|c'}
    assert_receive {:udp, _port, _from_ip, _from_port, 'myothercounter:1|c'}
  end

  test "flushes when the buffer gets too big" do
    DogStatsd.batch(:dogstatsd, fn s ->
      # increment a counter 50 times in batch
      Enum.each(1..51, fn _ ->
        s.increment(:dogstatsd, "mycounter")
      end)
    end)

    # We should receive a packet of 50 messages that was automatically
    # flushed when the buffer got too big
    theoretical_reply =
      Enum.into(1..50, [])
      |> Enum.map(fn _ -> "mycounter:1|c" end)
      |> Enum.join("\n")
      |> String.to_char_list()

    assert_receive {:udp, _port, _from_ip, _from_port, ^theoretical_reply}

    # When the block finishes, the remaining buffer is flushed
    assert_receive {:udp, _port, _from_ip, _from_port, 'mycounter:1|c'}
  end

  ########
  # event
  ########

  test "Only title and text" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event")

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event'}
  end

  test "With line break in Text and title" do
    title_break_line = "this is the title \n second line"
    text_break_line = "this is the event \n second line"
    DogStatsd.event(:dogstatsd, title_break_line, text_break_line)

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{32,32}:this is the title \\n second line|this is the event \\n second line'}
  end

  test "With known alert_type" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :alert_type => "warning"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|t:warning'}
  end

  test "With unknown alert_type" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :alert_type => "bizarre"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|t:bizarre'}
  end

  test "With known priority" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{:priority => "low"})

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|p:low'}
  end

  test "With unknown priority" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :priority => "bizarre"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|p:bizarre'}
  end

  test "With hostname" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :hostname => "hostname_test"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|h:hostname_test'}
  end

  test "With aggregation_key" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :aggregation_key => "aggkey 1"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|k:aggkey 1'}
  end

  test "With source_type_name" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :source_type_name => "source 1"
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|s:source 1'}
  end

  test "With several tags" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :tags => ["test:1", "test:2", "tags", "are", "fun"]
    })

    assert_receive {:udp, _port, _from_ip, _from_port,
                    '_e{17,17}:this is the title|this is the event|#test:1,test:2,tags,are,fun'}
  end

  test "With alert_type, priority, hostname, several tags" do
    DogStatsd.event(:dogstatsd, "this is the title", "this is the event", %{
      :alert_type => "warning",
      :priority => "low",
      :hostname => "hostname_test",
      :tags => ["test:1", "test:2", "tags", "are", "fun"]
    })

    test_string =
      '_e{17,17}:this is the title|this is the event|h:hostname_test|p:low|t:warning|#test:1,test:2,tags,are,fun'

    assert_receive {:udp, _port, _from_ip, _from_port, test_string}
  end
end
