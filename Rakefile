# frozen_string_literal: true

require "rubygems"
require "rake"

require "rspec/core/rake_task"
RSpec::Core::RakeTask.new(:rspec)

require "rubocop/rake_task"
RuboCop::RakeTask.new(:rubocop)

task default: %w[rubocop:autocorrect_all rspec]
task ci: %w[rubocop rspec]
