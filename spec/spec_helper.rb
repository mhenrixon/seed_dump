# frozen_string_literal: true

# Set the environment to "test" and point DATABASE_URL to an in-memory database.
ENV["RAILS_ENV"] = "test"
ENV["DATABASE_URL"] = "sqlite3::memory:"

require "rails/all"
require "tempfile"
require "pry-rails"
require "database_cleaner"
require "factory_bot"

# Create a minimal Rails application for testing
class TestApp < Rails::Application
  config.root = File.dirname(__FILE__)
  config.eager_load = false

  # Prevent Rails from loading real credentials
  config.secret_key_base = "test"
  config.secret_token = "test"

  # Configure Active Storage to use a local disk-based service
  config.active_storage.service = :test
  config.active_storage.service_configurations = {
    test: {
      service: "Disk",
      root: Rails.root.join("tmp/storage"),
    },
  }

  # Disable schema checks for this test-application setup
  config.active_record.maintain_test_schema = false

  # Raise errors when translations are missing
  config.action_view.raise_on_missing_translations = true

  # Enable ActiveRecord encryption
  config.active_record.encryption.support_unencrypted_data = true
  config.active_record.encryption.primary_key            = "test" * 4
  config.active_record.encryption.deterministic_key      = "test" * 4
  config.active_record.encryption.key_derivation_salt    = "test" * 4

  config.active_support.to_time_preserves_timezone = :zone
end

# Initialize Rails so that ActiveRecord, ActiveStorage, etc. are set up.
Rails.application.initialize!

##############################################################################
# WORKAROUND: Overriding Rails.config to avoid recursion
# Instead of calling Rails.application.config in Rails.config (which can cause
# infinite loops in some ActiveStorage versions), store application.config in
# a local variable, and return that from Rails.config.
##############################################################################
RAILS_CONFIG = Rails.application.config
class << Rails
  define_method(:config) do
    RAILS_CONFIG
  end
end

# Configure Active Storage for testing.
ActiveStorage::Engine.config.active_storage.service = :test
ActiveStorage::Blob.service = ActiveStorage::Blob.services.fetch(:test)

# Define an abstract ApplicationRecord so models can inherit from it.
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
end

# Load your library and any test helpers.
require "seed_dumpling"
require "./spec/helpers"
require "rack/test"
FactoryBot.find_definitions

# Configure RSpec.
RSpec.configure do |config|
  config.order = "random"

  config.include Helpers
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FileUtils.mkdir_p("db")
    FileUtils.touch("db/seeds.rb")

    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)

    FileUtils.mkdir_p(File.join(File.dirname(__FILE__), "tmp/storage"))
  end

  config.after(:suite) do
    FileUtils.rm_rf("blargle")
    FileUtils.rm_rf("db/seed.rb")
    FileUtils.rm_rf(File.join(File.dirname(__FILE__), "tmp/storage"))
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
