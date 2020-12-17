
dogstatsd-elixir
==============

A client for DogStatsd, an extension of the StatsD metric server for Datadog.

[![Build Status](https://travis-ci.org/adamkittelson/dogstatsd-elixir.svg?branch=master)](https://travis-ci.org/adamkittelson/dogstatsd-elixir)
[![Coverage Status](https://coveralls.io/repos/adamkittelson/dogstatsd-elixir/badge.png?branch=master)](https://coveralls.io/r/adamkittelson/dogstatsd-elixir?branch=master)

Quick Start Guide
-----------------

First install the library:

  1. Add dogstatsd to your `mix.exs` dependencies:

      ```elixir
      def deps do
        [
          {:dogstatsd, "0.0.5"}
        ]
      end
      ```

  2. Add `:dogstatsd` to your application dependencies:

      ```elixir
      def application do
        [applications: [:dogstatsd]]
      end
      ```

Then start instrumenting your code:

``` elixir
# Require the dogstatsd module.
require DogStatsd

# Configure DogStatsd.
{:ok, statsd} = DogStatsd.new("localhost", 8125)

# Increment a counter.
DogStatsd.increment(statsd, "page.views")

# Record a gauge 50% of the time.
DogStatsd.gauge(statsd, "users.online", 123, %{sample_rate: 0.5})

# Sample a histogram
DogStatsd.histogram(statsd, "file.upload.size", 1234)

# Time a block of code
DogStatsd.time(statsd, "page.render") do
  render_page('home.html')
end

# Send several metrics at the same time
# All metrics will be buffered and sent in one packet when the block completes
DogStatsd.batch(statsd, fn(s) ->
  s.increment(statsd, "page.views")
  s.gauge(statsd, "users.online", 123)
end)

# Tag a metric.
DogStatsd.histogram(statsd, "query.time", 10, %{tags: ["version:1"]})
```

You can also post events to your stream. You can tag them, set priority and even aggregate them with other events.

Aggregation in the stream is made on hostname/event_type/source_type/aggregation_key.

``` elixir
# Post a simple message
DogStatsd.event(statsd, "There might be a storm tomorrow", "A friend warned me earlier.")

# Cry for help
DogStatsd.event(statsd, "SO MUCH SNOW", "Started yesterday and it won't stop !!", %{alert_type: "error", tags: ["urgent", "endoftheworld"]})
```


Feedback
--------

To suggest a feature, report a bug, or general discussion, head over
[here](http://github.com/adamkittelson/dogstatsd-elixir/issues/).


Change Log
----------

- 0.0.1
    - Initial release.


Credits
-------

dogstatsd-elixir is a port of the [Ruby DogStatsd client](https://github.com/DataDog/dogstatsd-ruby)
