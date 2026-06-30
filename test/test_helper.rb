ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require_relative "test_helpers/session_test_helper"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...
    def with_rails_env(name)
      original_env = Rails.env
      env = ActiveSupport::StringInquirer.new(name)

      Rails.singleton_class.define_method(:env) { env }
      yield
    ensure
      Rails.singleton_class.define_method(:env) { original_env }
    end
  end
end
