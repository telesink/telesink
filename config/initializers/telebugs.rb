Sentry.init do |config|
  config.dsn = ENV["TELEBUGS_DSN"]
  config.breadcrumbs_logger = [:active_support_logger, :http_logger]
  config.send_default_pii = true
end
