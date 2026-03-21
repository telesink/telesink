source "https://rubygems.org"

ruby file: ".ruby-version"

gem "rails", "~> 8.1.2"

# Drivers
gem "pg", "~> 1.1"

# Deployment
gem "puma", ">= 5.0"
gem "thruster", require: false
gem "kamal", require: false

# Jobs
gem "solid_queue"
gem "mission_control-jobs"

# Front-end
gem "propshaft"
gem "importmap-rails"
gem "turbo-rails"
gem "stimulus-rails"

# Other
gem "bcrypt", "~> 3.1.7"
gem "solid_cache"
gem "solid_cable"
gem "sentry-rails"
gem "rack-cors"
gem "telesink"

group :development, :test do
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
end
