require "../src/prometheus"

# Create metrics
errors = Prometheus.counter("http_errors_total", "Total HTTP errors")
memory = Prometheus.gauge("memory_usage_bytes", "Current memory usage in bytes")
response_time = Prometheus.histogram(
  "http_response_time",
  "HTTP response time in seconds",
  [0.1, 0.3, 0.5, 1.0, 2.0]
)
request_size = Prometheus.summary("http_request_size_bytes", "HTTP request size in bytes")

# Simulate some traffic
puts "Simulating HTTP traffic..."

# Create a single counter with endpoint label
requests = Prometheus.counter(
  "http_requests_total",
  "Total HTTP requests",
)

# Simulate requests over 5 iterations
5.times do |i|
  labels = {
    "method"   => %w[GET POST].sample,
    "endpoint" => %w[/api /].sample,
  }

  # Simulate API requests
  requests.inc labels: labels
  response_time.observe(0.2, labels) # 200ms response time
  request_size.observe(512, labels)  # 512 bytes request size

  # Simulate web requests - Note: Currently limited by implementation
  # In a real Prometheus client, we would be able to increment with different labels
  requests.inc(labels: labels)
  response_time.observe(0.4, labels) # 400ms response time
  request_size.observe(1024, labels) # 1KB request size

  # Simulate some errors (20% error rate)
  errors.inc if i % 5 == 0

  # Simulate memory usage fluctuation
  memory.set(100_000 + (i * 10_000), labels) # Increasing memory usage

  sleep 1.seconds # Wait 1 second between iterations
end

puts "\nMetrics output:"
puts "=============="
Prometheus.collect STDOUT
