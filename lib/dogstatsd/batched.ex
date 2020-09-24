defmodule DogStatsd.Batched do
  @moduledoc false

  use DogStatsd.Statsd

  def send_to_socket(dogstatsd, message) do
    buffer = DogStatsd.add_to_buffer(dogstatsd, message)

    if length(buffer) == DogStatsd.max_buffer_size(dogstatsd) do
      DogStatsd.flush_buffer(dogstatsd)
    end
  end
end
