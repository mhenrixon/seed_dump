# frozen_string_literal: true

namespace :db do
  namespace :seed do
    desc "Dump records from the database into db/seeds.rb"
    task dump: :environment do
      SeedDumpling.dump_using_environment(ENV)
    end
  end
end
