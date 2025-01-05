# frozen_string_literal: true

require "ipaddr"
require "seed_dump/dump_methods/enumeration"
require "seed_dump/dump_methods"
require "seed_dump/environment"

# Tool for extracting database records into a format suitable for
# Rails' db/seeds.rb. Supports various data types and configurable output formats.
class SeedDump
  extend Environment
  extend DumpMethods

  require "seed_dump/railtie" if defined?(Rails)
end
