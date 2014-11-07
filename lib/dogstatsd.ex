defmodule DogStatsd do
  use GenServer
  require Logger

  @default_host "127.0.0.1"
  @default_port 8125

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

  def event(dogstatsd \\ :dogstatsd, title, text, opts \\ %{}) do
    opts = update_in opts, [:tags], &((tags(dogstatsd) ++ (&1 || [])) |> Enum.uniq)

    event_string = format_event(title, text, opts)

    if byte_size(event_string) > 8 * 1024 do
      Logger.warn "Event #{title} payload is too big (more that 8KB), event discarded"
    end

    send_to_socket dogstatsd, event_string
  end

  def format_event(title, text, opts \\ %{}) do
    title = escape_event_content(title)
    text  = escape_event_content(text)

    add_opts("_e{#{String.length(title)},#{String.length(text)}}:#{title}|#{text}", opts)
  end

  def add_opts(event, %{:date_happened    => opt} = opts), do: format_event("#{event}|d:#{rm_pipes(opt)}", Map.delete(opts, :date_happened))
  def add_opts(event, %{:hostname         => opt} = opts), do: format_event("#{event}|h:#{rm_pipes(opt)}", Map.delete(opts, :hostname))
  def add_opts(event, %{:aggregation_key  => opt} = opts), do: format_event("#{event}|k:#{rm_pipes(opt)}", Map.delete(opts, :aggregation_key))
  def add_opts(event, %{:priority         => opt} = opts), do: format_event("#{event}|p:#{rm_pipes(opt)}", Map.delete(opts, :priority))
  def add_opts(event, %{:source_type_name => opt} = opts), do: format_event("#{event}|s:#{rm_pipes(opt)}", Map.delete(opts, :source_type_name))
  def add_opts(event, %{:alert_type       => opt} = opts), do: format_event("#{event}|t:#{rm_pipes(opt)}", Map.delete(opts, :alert_type))
  def add_opts(event, %{} = opts), do: add_tags(event, opts[:tags])

  def add_tags(event, []), do: event
  def add_tags(event, tags) do
    tags = tags
           |> Enum.map(&rm_pipes/1)
           |> Enum.join(",")

    "#{event}|##{tags}"
  end

  def send_to_socket(dogstatsd \\ :dogstatsd, message)
  def send_to_socket(_dogstatsd, message) when byte_size(message) > 8 * 1024, do: nil
  def send_to_socket(dogstatsd, message) do
    Logger.debug "DogStatsd: #{message}"

    :gen_udp.send(socket(dogstatsd),
                  host(dogstatsd) |> String.to_char_list,
                  port(dogstatsd),
                  message |> String.to_char_list)
  end

  def escape_event_content(msg) do
    String.replace(msg, "\n", "\\n")
  end
  def rm_pipes(msg) do
    String.replace(msg, "|", "")
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

  def socket(dogstatsd) do
    GenServer.call(dogstatsd, :get_socket)
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

  def handle_call(:get_socket, _from, config) do
    {:reply, config[:socket], config}
  end

end
