require 'rubocop'
require 'fast'
require 'unparser'

module TheSchemaIs
  module Cop
    class Content < RuboCop::Cop::Cop
      # FAST docs: https://jonatas.github.io/fast/syntax/
    end
  end
end

require_relative 'the_schema_is/schema'
require_relative 'the_schema_is/model'
require_relative 'the_schema_is/differ'
