Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins "*"

    resource "/api/v1/sinks/*/events",
      headers: %w[Content-Type Idempotency-Key User-Agent Accept],
      methods: %i[post options],
      max_age: 7200
  end
end
