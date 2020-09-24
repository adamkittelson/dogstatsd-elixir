# credo:disable-for-this-file Credo.Check.Refactor.LongQuoteBlocks

defmodule DogStatsd.Statsd do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      require Logger

      def gauge(dogstatsd, stat, value, opts \\ %{}) do
        send_stats(dogstatsd, stat, value, :g, opts)
      end

      def event(dogstatsd, title, text, opts \\ %{}) do
        event_string = format_event(title, text, opts)

        if byte_size(event_string) > 8 * 1024 do
          Logger.warn("Event #{title} payload is too big (more that 8KB), event discarded")
        end

        send_to_socket(dogstatsd, event_string)
      end

      def format_event(title, text, opts \\ %{}) do
        title = escape_event_content(title)
        text = escape_event_content(text)

        add_opts("_e{#{String.length(title)},#{String.length(text)}}:#{title}|#{text}", opts)
      end

      def add_opts(event, %{:date_happened => opt} = opts),
        do: add_opts("#{event}|d:#{rm_pipes(opt)}", Map.delete(opts, :date_happened))

      def add_opts(event, %{:hostname => opt} = opts),
        do: add_opts("#{event}|h:#{rm_pipes(opt)}", Map.delete(opts, :hostname))

      def add_opts(event, %{:aggregation_key => opt} = opts),
        do: add_opts("#{event}|k:#{rm_pipes(opt)}", Map.delete(opts, :aggregation_key))

      def add_opts(event, %{:priority => opt} = opts),
        do: add_opts("#{event}|p:#{rm_pipes(opt)}", Map.delete(opts, :priority))

      def add_opts(event, %{:source_type_name => opt} = opts),
        do: add_opts("#{event}|s:#{rm_pipes(opt)}", Map.delete(opts, :source_type_name))

      def add_opts(event, %{:alert_type => opt} = opts),
        do: add_opts("#{event}|t:#{rm_pipes(opt)}", Map.delete(opts, :alert_type))

      def add_opts(event, %{} = opts), do: add_tags(event, opts[:tags])

      def add_tags(event, nil), do: event
      def add_tags(event, []), do: event

      def add_tags(event, tags) do
        tags =
          tags
          |> Enum.map(&rm_pipes/1)
          |> Enum.join(",")

        "#{event}|##{tags}"
      end

      def increment(dogstatsd, stat, opts \\ %{}) do
        count(dogstatsd, stat, 1, opts)
      end

      def decrement(dogstatsd, stat, opts \\ %{}) do
        count(dogstatsd, stat, -1, opts)
      end

      def count(dogstatsd, stat, count, opts \\ %{}) do
        send_stats(dogstatsd, stat, count, :c, opts)
      end

      def histogram(dogstatsd, stat, value, opts \\ %{}) do
        send_stats(dogstatsd, stat, value, :h, opts)
      end

      def timing(dogstatsd, stat, ms, opts \\ %{}) do
        send_stats(dogstatsd, stat, ms, :ms, opts)
      end

      defmacro time(dogstatsd, stat, opts \\ Macro.escape(%{}), do_block) do
        quote do
          function = fn -> unquote(do_block[:do]) end

          {elapsed, result} = :timer.tc(DogStatsd, :_time_apply, [function])

          DogStatsd.timing(
            unquote(dogstatsd),
            unquote(stat),
            trunc(elapsed / 1000),
            unquote(opts)
          )

          result
        end
      end

      def _time_apply(function), do: function.()

      def set(dogstatsd, stat, value, opts \\ %{}) do
        send_stats(dogstatsd, stat, value, :s, opts)
      end

      def batch(dogstatsd, function) do
        function.(DogStatsd.Batched)
        DogStatsd.flush_buffer(dogstatsd)
      end

      def send_stats(dogstatsd, stat, delta, type, opts \\ %{})

      def send_stats(dogstatsd, stat, delta, type, %{:sample_rate => _sample_rate} = opts) do
        opts = Map.put(opts, :sample, :rand.uniform())

        send_to_socket(
          dogstatsd,
          get_global_tags_and_format_stats(dogstatsd, stat, delta, type, opts)
        )
      end

      def send_stats(dogstatsd, stat, delta, type, opts) do
        send_to_socket(
          dogstatsd,
          get_global_tags_and_format_stats(dogstatsd, stat, delta, type, opts)
        )
      end

      def get_global_tags_and_format_stats(dogstatsd, stat, delta, type, opts) do
        opts =
          update_in(opts, [:tags], &((DogStatsd.tags(dogstatsd) ++ (&1 || [])) |> Enum.uniq()))

        format_stats(dogstatsd, stat, delta, type, opts)
      end

      def format_stats(_dogstatsd, _stat, _delta, _type, %{:sample_rate => sr, :sample => s})
          when s > sr,
          do: nil

      def format_stats(dogstatsd, stat, delta, type, %{:sample => s} = opts),
        do: format_stats(dogstatsd, stat, delta, type, Map.delete(opts, :sample))

      def format_stats(dogstatsd, stat, delta, type, %{:sample_rate => sr} = opts) do
        "#{DogStatsd.prefix(dogstatsd)}#{format_stat(stat)}:#{delta}|#{type}|@#{sr}"
        |> add_tags(opts[:tags])
      end

      def format_stats(dogstatsd, stat, delta, type, opts) do
        "#{DogStatsd.prefix(dogstatsd)}#{format_stat(stat)}:#{delta}|#{type}"
        |> add_tags(opts[:tags])
      end

      def format_stat(stat) do
        String.replace(stat, ~r/[:|@]/, "_")
      end

      def send_to_socket(_dogstatsd, nil), do: nil
      def send_to_socket(_dogstatsd, []), do: nil
      def send_to_socket(_dogstatsd, message) when byte_size(message) > 8 * 1024, do: nil

      def send_to_socket(dogstatsd, message) do
        {:ok, socket} = :gen_udp.open(0)

        :gen_udp.send(
          socket,
          host(dogstatsd) |> String.to_charlist(),
          port(dogstatsd),
          message |> String.to_char_list()
        )

        :gen_udp.close(socket)
      end

      def escape_event_content(msg) do
        String.replace(msg, "\n", "\\n")
      end

      def rm_pipes(msg) do
        String.replace(msg, "|", "")
      end

      defoverridable send_to_socket: 2
    end
  end
end
