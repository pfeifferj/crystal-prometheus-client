# Core data model types for the Prometheus client library.
module Prometheus
  # A Label represents a key-value pair used to identify a metric.
  #
  # Labels are used to distinguish different dimensions of a metric. For example,
  # an HTTP request counter might have labels for the method and path.
  #
  # ```
  # label = Label.new("method", "GET")
  # ```
  #
  # Label names must match the regex `[a-zA-Z_][a-zA-Z0-9_]*` and cannot be empty.
  # Label values cannot be empty.
  class Label
    getter name : String
    getter value : String

    def initialize(@name : String, @value : String)
      validate_name
      validate_value
    end

    private def validate_name
      raise ArgumentError.new("Label name cannot be empty") if @name.empty?
      raise ArgumentError.new("Invalid label name: #{@name}") unless @name =~ /^[a-zA-Z_][a-zA-Z0-9_]*$/
    end

    private def validate_value
      raise ArgumentError.new("Label value cannot be empty") if @value.empty?
    end
  end

  # LabelSet represents a collection of labels that uniquely identify a metric.
  #
  # A LabelSet is used to attach multiple labels to a metric, enabling Prometheus's
  # dimensional data model.
  #
  # ```
  # labels = LabelSet.new({
  #   "method" => "GET",
  #   "path"   => "/api/users",
  # })
  # ```
  #
  # LabelSets can be merged to combine labels from different sources:
  #
  # ```
  # base_labels = LabelSet.new({"service" => "web"})
  # request_labels = LabelSet.new({"method" => "GET"})
  # combined = base_labels.merge(request_labels)
  # ```
  class LabelSet
    include Enumerable({String, String})

    getter labels : Hash(String, String)

    def initialize(@labels = Hash(String, String).new)
    end

    def add(name : String, value : String)
      @labels[name] = value
    end

    def merge(other : LabelSet)
      merge other.labels
    end

    def merge(other : Hash(String, String))
      LabelSet.new(labels.merge(other))
    end

    def []?(label : String)
      @labels[label]?
    end

    delegate each, to: labels
    def_equals_and_hash labels

    def to_s(io : IO)
      return if @labels.empty?

      first = true
      io << "{"
      @labels.each do |name, value|
        io << "," unless first
        first = false
        io << "#{name}=\"#{value}\""
      end
      io << "}"
    end
  end

  # Base class for all metric types (Counter, Gauge, Histogram, Summary).
  #
  # This abstract class defines the common interface and behavior for all metrics:
  # * Each metric has a name, help text, and optional labels
  # * Names must match the regex `[a-zA-Z_:][a-zA-Z0-9_:]*`
  # * Each metric type must implement `type` and `collect` methods
  #
  # Metric implementations should be thread-safe and handle concurrent access appropriately.
  abstract class Metric
    alias Labels = LabelSet | Hash(String, String)

    getter name : String
    getter help : String
    getter labels : LabelSet

    def initialize(name : String, help : String, labels : Hash(String, String) = nil)
      initialize name, help, LabelSet.new(labels)
    end

    def initialize(@name : String, @help : String, @labels = LabelSet.new)
      validate_name
    end

    protected getter store : DataStore = DataStore.new

    private def label_set_for(labels : Hash(String, String)) : LabelSet
      label_set_for LabelSet.new(labels)
    end

    private def label_set_for(labels : LabelSet) : LabelSet
      @labels.merge(labels)
    end

    private def label_set_for(labels : Nil) : LabelSet
      @labels
    end

    private def validate_name
      raise ArgumentError.new("Metric name cannot be empty") if @name.empty?
      raise ArgumentError.new("Invalid metric name: #{@name}") unless @name =~ /^[a-zA-Z_:][a-zA-Z0-9_:]*$/
    end

    abstract def type : String

    def collect : Array(Sample)
      store.map do |label_set, value|
        Sample.new(@name, label_set, value)
      end
    end
  end

  # Represents a single sample value at a point in time.
  #
  # A Sample combines:
  # * A metric name
  # * A set of labels
  # * A numeric value
  # * An optional timestamp
  #
  # Samples are used to represent the actual data points collected by metrics.
  # The Sample format follows the Prometheus exposition format:
  #
  # ```text
  # metric_name{label="value"} 42
  # # Or with timestamp:
  # metric_name{label="value"} 42 1234567890
  # ```
  class Sample
    getter name : String
    getter labels : LabelSet
    getter value : Float64
    getter timestamp : Int64?

    def self.new(name : String, labels : Hash(String, String), value : Float64, timestamp : Int64? = nil)
      new name, LabelSet.new(labels), value, timestamp
    end

    def initialize(@name : String, @labels : LabelSet, @value : Float64, @timestamp : Int64? = nil)
    end

    def to_s(io : IO)
      io << @name
      io << @labels
      io << " "
      io << @value
      if timestamp = @timestamp
        io << " "
        io << timestamp
      end
    end

    def_equals_and_hash name, labels, value, timestamp
  end

  class DataStore
    include Enumerable({LabelSet, Float64})
    private alias Data = Hash(LabelSet, Float64)
    @data = Data.new { |data, labels| data[labels] = 0.0 }
    @mutex = Mutex.new

    def set(value : Float64, labels : LabelSet) : Nil
      sync { @data[labels] = value }
    end

    def inc(value : Float64, labels : LabelSet) : Nil
      sync { @data[labels] += value }
    end

    def dec(value : Float64, labels : LabelSet) : Nil
      inc -1, labels
    end

    def get(labels : LabelSet) : Float64
      sync { @data.fetch(labels, 0.0) }
    end

    delegate each, to: @data

    private def sync(&)
      @mutex.synchronize { yield }
    end
  end
end
