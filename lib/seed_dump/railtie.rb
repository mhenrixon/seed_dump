# frozen_string_literal: true

class SeedDump
  # Rails integration to load seed_dump rake tasks into the application.
  # Provides the db:seed:dump task for database record extraction.
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/seed_dump.rake"
    end
  end
end
