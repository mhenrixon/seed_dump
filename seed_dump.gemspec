# frozen_string_literal: true

require_relative "lib/seed_dumpling/version"

Gem::Specification.new do |spec|
  spec.name        = "seed_dumpling"
  spec.version     = SeedDumpling::VERSION
  spec.summary     = "Seed Dumper for Rails"
  spec.description = "Dump (parts) of your database to db/seedspec.rb to get a headstart creating a meaningful seedspec.rb file."
  spec.authors     = ["Mikael Henriksson"]
  spec.email       = "mikael@mhenrixon.com"
  spec.homepage    = "https://github.com/mhenrixon/dumpling"
  spec.license     = "MIT"

  spec.required_ruby_version = ">= 3.2.0"

  spec.require_paths = ["lib"]
  spec.files         = Dir.glob("lib/**/*") + ["README.md", "LICENSE.txt"]

  spec.add_dependency "activerecord-import"
  spec.add_dependency "rails", ">= 7.0", "< 9.0"

  spec.metadata = {
    "rubygems_mfa_required" => "true",
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => "#{spec.homepage}/blob/up/CHANGELOG.md",
  }
end
