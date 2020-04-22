# frozen_string_literal: true

require 'rubocop'

require 'rubocop/rspec/support'
require 'the_schema_is'
require 'the_schema_is/cops'

require 'rspec/its'
require 'saharspec'
require 'rubocop/rspec/support'

# require 'byebug'

RSpec.configure do |config|
  config.order = :random

  # Forbid RSpec from monkey patching any of our objects
  config.disable_monkey_patching!

  # We should address configuration warnings when we upgrade
  config.raise_errors_for_deprecations!

  config.include(RuboCop::RSpec::ExpectOffense)
end

# It is defined in rubocop/rspec/shared_contexts.rb, but forgets to merge namespace's config, which
# is important for TheSchemaIs
RSpec.shared_context 'config_ns', :config_ns do
  let(:config) do
    # Module#<
    unless described_class < RuboCop::Cop::Cop
      raise '`config` must be used in `describe SomeCopClass do .. end`'
    end

    hash = { 'AllCops' => { 'TargetRubyVersion' => ruby_version } }
    hash['AllCops']['TargetRailsVersion'] = rails_version if rails_version
    if respond_to?(:cop_config)
      cop_name = described_class.cop_name
      hash[cop_name] = RuboCop::ConfigLoader
                       .default_configuration[cop_name]
                       .merge('Enabled' => true) # in case it is 'pending'
                       .merge(cop_config)
      # ONLY this two lines added comparing to Rubocop's default context!
      namespace = cop_name.split('/').first
      hash[namespace] = RuboCop::ConfigLoader
                       .default_configuration[namespace]
    end

    hash = other_cops.merge hash if respond_to?(:other_cops)

    RuboCop::Config.new(hash, "#{Dir.pwd}/.rubocop.yml")
  end
end
