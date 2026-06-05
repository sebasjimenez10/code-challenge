# frozen_string_literal: true

require "rspec/core/rake_task"
require "standard/rake"

RSpec::Core::RakeTask.new(:spec)

desc "Run the specs and the linter"
task default: %i[spec standard]
