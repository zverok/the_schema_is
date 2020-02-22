require 'active_support/inflector'

module TheSchemaIs
  class Model < Struct.new(:class_name, :table_name, :source, :schema, keyword_init: true)
    def self.parse(code)
      ast = Fast.ast(code)

      # TODO:
      # * also descendants of ApplicationRecord
      # * then, also configurable "base classes" list
      Fast.search('(class $_ (const (const nil :ActiveRecord) :Base))', ast).each_slice(2)
          .map { |node, name|
            class_name = Unparser.unparse(name.first)
            schema = Fast.search('(block (send nil :the_schema_is) _ $...', node)&.last
            new(
              class_name: class_name,
              # TODO:
              # * search for self.table_name = ...
              # * check with namespaces and other stuff
              # * then, allow to configure in other ways
              table_name: ActiveSupport::Inflector.tableize(class_name),
              source: node,
              schema: schema
            )
          }
    end
  end
end
