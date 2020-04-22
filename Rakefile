require 'bundler/setup'
$LOAD_PATH.unshift 'lib'
require 'pathname'
require 'rubygems/tasks'
Gem::Tasks.new

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new

task default: %w[spec rubocop]
