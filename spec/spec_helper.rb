# frozen_string_literal: true

require "seed_dump"

require "active_support"
require "active_record"

require "tempfile"

require "pry-rails"

require "database_cleaner"
require "factory_bot"

require "./spec/helpers"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

FactoryBot.find_definitions

RSpec.configure do |config|
  config.order = "random"

  config.include Helpers
  config.include FactoryBot::Syntax::Methods

  config.before(:suite) do
    FileUtils.mkdir_p("db")
    FileUtils.touch("db/seeds.rb")

    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.after(:suite) do 
    FileUtils.rm_rf("blargle")
    FileUtils.rm_rf("db/seed.rb")
  end

  config.before do
    DatabaseCleaner.start
  end

  config.after do
    DatabaseCleaner.clean
  end
end
