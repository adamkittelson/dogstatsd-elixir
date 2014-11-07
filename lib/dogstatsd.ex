defmodule DogStatsd do
  use GenServer

  @default_host "127.0.0.1"
  @default_port 8125

  @opts_keys [
    ["date_happened", "d"],
    ["hostname", "h"],
    ["aggregation_key", "k"],
    ["priority", "p"],
    ["source_type_name", "s"],
    ["alert_type", "t"]
  ]

  def new do
    start_link(%{})
  end

  def new(host, port, opts \\ %{}) do
    config = opts
             |> Map.put_new(:host, host)
             |> Map.put_new(:port, port)
    start_link(config)
  end

  def start_link(config, options \\ []) do
    {:ok, socket} = :gen_udp.open(config[:outgoing_port] || 8789)

    config = config
             |> Map.take([:host, :port, :namespace, :tags, :max_buffer_size])
             |> Map.put_new(:max_buffer_size, 50)
             |> Map.put_new(:buffer, [])
             |> Map.put_new(:socket, socket)


    GenServer.start_link(__MODULE__, config, options)
  end

  def namespace(dogstatsd) do
    GenServer.call(dogstatsd, :get_namespace)
  end

  def namespace(dogstatsd, namespace) do
    GenServer.call(dogstatsd, {:set_namespace, namespace})
  end

  def host(dogstatsd) do
    GenServer.call(dogstatsd, :get_host) || System.get_env("DD_AGENT_ADDR") || @default_host
  end

  def host(dogstatsd, host) do
    GenServer.call(dogstatsd, {:set_host, host})
  end

  def port(dogstatsd) do
    GenServer.call(dogstatsd, :get_port) || System.get_env("DD_AGENT_PORT") || @default_port
  end

  def port(dogstatsd, port) do
    GenServer.call(dogstatsd, {:set_host, port})
  end

  def tags(dogstatsd) do
    GenServer.call(dogstatsd, :get_tags) || []
  end

  def tags(dogstatsd, tags) do
    GenServer.call(dogstatsd, {:set_tags, tags})
  end


  ###################
  # Server Callbacks

  def init(config) do
    {:ok, config}
  end

  def handle_call(:get_namespace, _from, config) do
    {:reply, config[:namespace], config}
  end

  def handle_call({:set_namespace, nil}, _from, config) do
    config = config
             |> Map.put(:namespace, nil)
             |> Map.put(:prefix, nil)

    {:reply, config[:namespace], config}
  end

  def handle_call({:set_namespace, namespace}, _from, config) do
    config = config
             |> Map.put(:namespace, namespace)
             |> Map.put(:prefix, "#{namespace}.")

    {:reply, config[:namespace], config}
  end

  def handle_call(:get_host, _from, config) do
    {:reply, config[:host], config}
  end

  def handle_call({:set_host, host}, _from, config) do
    config = config
             |> Map.put(:host, host)

    {:reply, config[:host], config}
  end

  def handle_call(:get_port, _from, config) do
    {:reply, config[:port], config}
  end

  def handle_call({:set_port, port}, _from, config) do
    config = config
             |> Map.put(:port, port)

    {:reply, config[:port], config}
  end

  def handle_call(:get_tags, _from, config) do
    {:reply, config[:tags], config}
  end

  def handle_call({:set_tags, tags}, _from, config) do
    config = config
             |> Map.put(:tags, tags)

    {:reply, config[:tags], config}
  end

end
