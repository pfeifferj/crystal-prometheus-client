require "./types"

# Registry functionality for managing and collecting metrics.
module Prometheus
  # Registry stores and manages the collection of metrics.
  #
  # The Registry is responsible for:
  # * Storing metric instances
  # * Ensuring metric names are unique
  # * Collecting metrics in Prometheus text format
  #
  # A default registry is provided via `Prometheus.register`, but you can also create
  # your own registries if needed:
  #
  # ```
  # # Using default registry
  # Prometheus.register(metric)
  # output = Prometheus.collect
  #
  # # Using custom registry
  # registry = Registry.new
  # registry.register(metric)
  # output = registry.collect
  # ```
  #
  # The registry ensures thread-safe access to metrics and provides proper
  # synchronization for concurrent operations.
  class Registry
    @metrics = {} of String => Metric
    @mutex = Mutex.new

    # Registers a metric with this registry.
    #
    # Each metric name must be unique within a registry. Attempting to register
    # a metric with a name that's already in use will raise an ArgumentError.
    #
    # ```
    # counter = Counter.new("http_requests_total", "Total HTTP requests")
    # registry.register(counter)
    # ```
    #
    # Raises:
    # * ArgumentError if a metric with the same name is already registered
    def register(metric : Metric)
      @mutex.synchronize do
        if @metrics[metric.name]?
          raise ArgumentError.new("Metric #{metric.name} already registered")
        end
        @metrics[metric.name] = metric
      end
    end

    # Unregisters a metric by name.
    #
    # ```
    # registry.unregister("http_requests_total")
    # ```
    def unregister(name : String)
      @mutex.synchronize do
        @metrics.delete(name)
      end
    end

    # Removes all metrics from the registry.
    #
    # ```
    # registry.clear
    # ```
    def clear
      @mutex.synchronize do
        @metrics.clear
      end
    end

    # Collects all registered metrics and returns them in Prometheus text format.
    #
    # The output format follows the Prometheus exposition format:
    # ```text
    # # HELP http_requests_total Total HTTP requests
    # # TYPE http_requests_total counter
    # http_requests_total{method="GET"} 42
    # ```
    #
    # ```
    # output = registry.collect
    # puts output
    # ```
    def collect : String
      String.build do |io|
        collect io
      end
    end

    def collect(io : IO) : Nil
      @mutex.synchronize do
        @metrics.each do |_, metric|
          # Write help comment
          io << "# HELP " << metric.name << " " << metric.help << "\n"
          # Write type comment
          io << "# TYPE " << metric.name << " " << metric.type << "\n"
          # Write samples
          metric.collect.each do |sample|
            io << sample << "\n"
          end
        end
      end
    end

    # Default global registry instance
    class_getter default : Registry = Registry.new
  end
end
