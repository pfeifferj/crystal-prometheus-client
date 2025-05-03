require "./types"

# Implementation of Prometheus metric types.
module Prometheus
  # A Counter is a cumulative metric that represents a single monotonically increasing counter
  # whose value can only increase or be reset to zero.
  #
  # Use a Counter for metrics that accumulate values, such as:
  # * Number of requests served
  # * Number of tasks completed
  # * Number of errors
  #
  # Example:
  # ```
  # counter = Counter.new("http_requests_total", "Total HTTP requests")
  # counter.inc    # Increment by 1
  # counter.inc(5) # Increment by 5
  # ```
  #
  # NOTE: Counter values cannot decrease. Use a Gauge for values that can go up and down.
  class Counter < Metric
    def type : String
      "counter"
    end

    def inc(value : Number = 1, labels : LabelSet? = nil)
      raise ArgumentError.new("Counter increment must be positive") if value < 0
      store.inc value.to_f64, label_set_for(labels)
    end

    def inc!(value : Number = 1, labels : LabelSet? = nil)
      raise ArgumentError.new("Counter increment must be positive") if value < 0
      store.inc! value.to_f64, label_set_for(labels)
    end

    def value(labels : LabelSet? = nil) : Float64
      store.get label_set_for(labels)
    end
  end

  # A Gauge is a metric that represents a single numerical value that can arbitrarily go up and down.
  #
  # Use a Gauge for metrics that can increase and decrease, such as:
  # * Current memory usage
  # * Number of items in a queue
  # * Number of active connections
  #
  # Example:
  # ```
  # gauge = Gauge.new("cpu_usage", "CPU usage percentage")
  # gauge.set(45.2) # Set to specific value
  # gauge.inc(5)    # Increase by 5
  # gauge.dec(3)    # Decrease by 3
  # ```
  class Gauge < Metric
    def type : String
      "gauge"
    end

    def set(value : Number, labels : Labels? = nil)
      store.set value, label_set_for(labels)
    end

    def inc(value : Number = 1, labels : Labels? = nil)
      store.inc value, label_set_for(labels)
    end

    def dec(value : Number = 1, labels : Labels? = nil)
      store.dec value, label_set_for(labels)
    end

    def value(labels : Labels? = nil) : Float64
      store.get label_set_for(labels)
    end
  end

  # A Histogram samples observations (usually things like request durations or response sizes)
  # and counts them in configurable buckets.
  #
  # Use a Histogram to track size distributions, such as:
  # * Request duration
  # * Response sizes
  # * Queue length variations
  #
  # Example:
  # ```
  # # Create with custom buckets
  # histogram = Histogram.new(
  #   "response_time",
  #   "Response time in seconds",
  #   [0.1, 0.5, 1.0, 2.0, 5.0]
  # )
  #
  # # Observe values
  # histogram.observe(0.25)
  # ```
  #
  # Histograms track:
  # * Count per bucket (number of values <= bucket upper bound)
  # * Total sum of all observed values
  # * Count of all observed values
  class Histogram < Metric
    @buckets : Array({Float64, Counter})
    @mutex = Mutex.new
    @count : Counter
    @sum : Counter

    def initialize(name : String, help : String, buckets : Array(Float64), labels = LabelSet.new)
      super(name, help, labels)
      @count = Counter.new("#{name}_count", help, labels: labels)
      @sum = Counter.new("#{name}_sum", help, labels: labels)
      @buckets = buckets.sort.map do |bucket|
        counter = Counter.new("#{name}_bucket", help, labels: labels.merge({
          "le" => bucket.to_s,
        }))
        counter.store.set 0f64, counter.labels

        {bucket, counter}
      end
      infinity = Counter.new("#{name}_bucket", help, labels: labels.merge({"le" => "+Inf"}))
      @buckets << {
        Float64::INFINITY,
        infinity,
      }
      infinity.store.set 0f64, infinity.labels
    end

    def type : String
      "histogram"
    end

    def observe(value : Number, labels : Labels? = nil)
      @mutex.synchronize do
        @count.inc! 1, labels
        @sum.inc! value, labels
        @buckets.each do |upper_bound, bucket|
          if value <= upper_bound
            inc = 1
          else
            inc = 0
          end
          bucket.inc! inc, labels
        end
      end
    end

    def collect : Array(Sample)
      @mutex.synchronize do
        samples = Array(Sample).new(@buckets.size + 2)
          .concat(@count.collect)
          .concat(@sum.collect)

        @buckets.each do |upper_bound, bucket|
          samples.concat bucket.collect
        end

        samples
      end
    end
  end

  # A Summary captures individual observations from an event or sample stream
  # and summarizes them with count and sum.
  #
  # Use a Summary for metrics where you need the count and sum, such as:
  # * Request latencies
  # * Request sizes
  # * Response sizes
  #
  # Example:
  # ```
  # summary = Summary.new("request_size", "Request size in bytes")
  # summary.observe(1024)
  # ```
  #
  # Summaries track:
  # * Count of all observed values
  # * Sum of all observed values
  class Summary < Metric
    @mutex = Mutex.new
    @count : Counter
    @sum : Counter

    def initialize(name : String, help : String, labels = LabelSet.new)
      super(name, help, labels)
      @count = Counter.new("#{name}_count", help, labels)
      @sum = Counter.new("#{name}_sum", help, labels)
    end

    def type : String
      "summary"
    end

    def observe(value : Number, labels : LabelSet? = nil)
      @mutex.synchronize do
        @count.inc! 1, labels
        @sum.inc! value, labels
      end
    end

    def collect : Array(Sample)
      @mutex.synchronize do
        Array(Sample).new(labels.size * 2)
          .concat(@count.collect)
          .concat(@sum.collect)
      end
    end
  end
end
