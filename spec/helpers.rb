# frozen_string_literal: true

# Mock Rails.application.eager_load! and define some
# Rails models for use in specs.
module Rails
  def self.application
    self
  end

  # rubocop:disable ThreadSafety/ClassInstanceVariable
  def self.eager_load!
    @already_called ||= false

    return if @already_called

    Object.const_set(:Sample, Class.new(ApplicationRecord))
    Object.const_set(:AnotherSample, Class.new(ApplicationRecord))
    Object.const_set(:YetAnotherSample, Class.new(ApplicationRecord))
    Object.const_set(:NoTableModel, Class.new(ApplicationRecord))
    Object.const_set(:EmptyModel, Class.new(ApplicationRecord))

    @already_called = true
  end
  # rubocop:enable ThreadSafety/ClassInstanceVariable

  def self.env
    "test"
  end
end

module Helpers
  def create_db # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    ActiveRecord::Migration.verbose = false

    ActiveRecord::Schema.define(version: 1) do
      create_table "samples", force: true do |t|
        t.string   "string"
        t.text     "text"
        t.integer  "integer"
        t.float    "float"
        t.decimal  "decimal"
        t.datetime "datetime"
        t.time     "time"
        t.date     "date"
        t.binary   "binary"
        t.boolean  "boolean"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
      end

      create_table "another_samples", force: true do |t|
        t.string   "string"
        t.text     "text"
        t.integer  "integer"
        t.float    "float"
        t.decimal  "decimal"
        t.datetime "datetime"
        t.time     "time"
        t.date     "date"
        t.binary   "binary"
        t.boolean  "boolean"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
      end

      create_table "yet_another_samples", force: true do |t|
        t.string   "string"
        t.text     "text"
        t.integer  "integer"
        t.float    "float"
        t.decimal  "decimal"
        t.datetime "datetime"
        t.time     "time"
        t.date     "date"
        t.binary   "binary"
        t.boolean  "boolean"
        t.datetime "created_at", null: false
        t.datetime "updated_at", null: false
      end

      create_table "empty_models", force: true
    end
  end

  def fixture_file(filename)
    file_path = File.join(__dir__, "fixtures", "files", filename)
    raise "Fixture file '#{filename}' does not exist" unless File.exist?(file_path)

    # Return a new file handle each time to avoid reuse issues
    File.open(file_path, "rb")
  end

  def load_sample_data
    Rails.application.eager_load!

    Sample.create!

    ChildSample.create!
  end
end
