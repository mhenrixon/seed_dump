# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = "seed_dumper"
  s.version     = "1.0.0"
  s.summary     = "Seed Dumper for Rails"
  s.description = "Dump (parts) of your database to db/seeds.rb to get a headstart creating a meaningful seeds.rb file"
  s.authors     = ["Mikael Henriksson"]
  s.email       = "mikael@mhenrixon.com"
  s.homepage    = "https://github.com/rroblak/seed_dump"
  s.licenses    = ["MIT"]

  s.require_paths = ["lib"]
  s.files         = Dir.glob("lib/**/*") + ["README.md", "MIT-LICENSE"]

  s.add_dependency "activerecord"
  s.add_dependency "activerecord-import"
  s.add_dependency "activesupport"

  s.metadata = {
    "rubygems_mfa_required" => "true",
  }
end
