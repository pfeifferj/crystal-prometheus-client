require "./types"
require "./metrics"
require "./registry"

# A Crystal client library for Prometheus monitoring system.
#
# This library provides a complete implementation of Prometheus client library guidelines,
# including support for all metric types (Counter, Gauge, Histogram, Summary),
# label sets, and thread-safe operations.
#
# ## Basic Usage
#
# ```
# # Create metrics
# counter = Prometheus.counter("http_requests_total", "Total HTTP requests")
# gauge = Prometheus.gauge("cpu_usage", "CPU usage percentage")
# histogram = Prometheus.histogram("response_time", "Response time in seconds", [0.1, 0.5, 1.0])
# summary = Prometheus.summary("request_size", "Request size in bytes")
#
# # Add labels
# labels = Prometheus::LabelSet.new({"method" => "GET", "path" => "/api"})
# requests = Prometheus.counter("http_requests_total", "Total HTTP requests", labels)
#
# # Use metrics
# counter.inc
# gauge.set(45.2)
# histogram.observe(0.25)
# summary.observe(1024)
#
# # Get metrics in Prometheus text format
# puts Prometheus.collect
# ```
module Prometheus
  VERSION = "0.1.0"

  # Creates and registers a new Counter metric.
  #
  # A Counter is a cumulative metric that represents a single monotonically increasing counter
  # whose value can only increase or be reset to zero.
  #
  # ```
  # counter = Prometheus.counter("http_requests_total", "Total HTTP requests")
  # counter.inc    # Increment by 1
  # counter.inc(5) # Increment by 5
  # ```
  #
  # Parameters:
  # * name : The name of the counter metric
  # * help : Help text describing the metric
  # * labels : Optional LabelSet for dimensional data
  def self.register(metric : Metric)
    Registry.default.register(metric)
  end

  def self.unregister(name : String)
    Registry.default.unregister(name)
  end

  def self.clear
    Registry.default.clear
  end

  def self.collect(io : IO) : Nil
    Registry.default.collect io
  end

  def self.collect : String
    Registry.default.collect
  end

  # Creates and registers a new Gauge metric.
  #
  # A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
  #
  # ```
  # gauge = Prometheus.gauge("cpu_usage", "CPU usage percentage")
  # gauge.set(45.2) # Set to 45.2
  # gauge.inc(5)    # Increase by 5
  # gauge.dec(3)    # Decrease by 3
  # ```
  #
  # Parameters:
  # * name : The name of the gauge metric
  # * help : Help text describing the metric
  # * labels : Optional LabelSet for dimensional data
  def self.counter(name : String, help : String, labels = LabelSet.new) : Counter
    counter = Counter.new(name, help, labels)
    register(counter)
    counter
  end

  def self.gauge(name : String, help : String, labels = LabelSet.new) : Gauge
    gauge = Gauge.new(name, help, labels)
    register(gauge)
    gauge
  end

  # Creates and registers a new Histogram metric.
  #
  # A Histogram samples observations (usually things like request durations or response sizes)
  # and counts them in configurable buckets.
  #
  # ```
  # histogram = Prometheus.histogram(
  #   "response_time",
  #   "Response time in seconds",
  #   [0.1, 0.5, 1.0, 2.0, 5.0]
  # )
  # histogram.observe(0.25)
  # ```
  #
  # Parameters:
  # * name : The name of the histogram metric
  # * help : Help text describing the metric
  # * buckets : Array of upper bounds for histogram buckets
  # * labels : Optional LabelSet for dimensional data
  def self.histogram(name : String, help : String, buckets : Array(Float64), labels = LabelSet.new) : Histogram
    histogram = Histogram.new(name, help, buckets, labels)
    register(histogram)
    histogram
  end

  # Creates and registers a new Summary metric.
  #
  # A Summary captures individual observations from an event or sample stream
  # and summarizes them in a traditional way, with count and sum.
  #
  # ```
  # summary = Prometheus.summary("request_size", "Request size in bytes")
  # summary.observe(1024)
  # ```
  #
  # Parameters:
  # * name : The name of the summary metric
  # * help : Help text describing the metric
  # * labels : Optional LabelSet for dimensional data
  def self.summary(name : String, help : String, labels = LabelSet.new) : Summary
    summary = Summary.new(name, help, labels)
    register(summary)
    summary
  end
end
