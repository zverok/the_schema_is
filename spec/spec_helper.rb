require 'rubocop'

require 'rubocop/rspec/support'
require 'the_schema_is'

require 'rspec/its'
require 'saharspec'

RSpec.configure do |config|

  config.order = :random

  # Forbid RSpec from monkey patching any of our objects
  config.disable_monkey_patching!

  # We should address configuration warnings when we upgrade
  config.raise_errors_for_deprecations!

  config.include(RuboCop::RSpec::ExpectOffense)
end
