# frozen_string_literal: true

require "ipaddr"
require "seed_dumpling/dump_methods/enumeration"
require "seed_dumpling/dump_methods"
require "seed_dumpling/environment"

# Tool for extracting database records into a format suitable for
# Rails' db/seeds.rb. Supports various data types and configurable output formats.
class SeedDumpling
  extend Environment
  extend DumpMethods

  require "seed_dumpling/railtie" if defined?(Rails)
end
