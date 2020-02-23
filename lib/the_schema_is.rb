require 'rubocop'
require 'fast'
require 'backports/latest'

module TheSchemaIs
end

require_relative 'the_schema_is/node_util'

require_relative 'the_schema_is/inject'

TheSchemaIs::Inject.defaults!

require_relative 'the_schema_is/parser'
require_relative 'the_schema_is/cops'
