# frozen_string_literal: true

class SeedDumpling
  class Railtie < Rails::Railtie
    rake_tasks do
      load "tasks/seed_dumpling.rake"
    end
  end
end
