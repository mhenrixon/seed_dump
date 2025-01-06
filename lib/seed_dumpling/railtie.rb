# frozen_string_literal: true

class SeedDumpling
  # Rails integration for SeedDupling
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/seed_dumpling.rake"
    end
  end
end
