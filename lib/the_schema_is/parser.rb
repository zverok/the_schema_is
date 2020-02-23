require 'active_support/inflector'

module TheSchemaIs
  module Parser
    # See https://github.com/rails/rails/blob/f33d52c95217212cbacc8d5e44b5a8e3cdc6f5b3/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb#L217
    # TODO: numeric is just an alias for decimal
    # TODO: different adapters can add another types (jsonb for Postgres)
    COLUMN_TYPES = [:bigint, :binary, :boolean, :date, :datetime, :decimal, :numeric,
          :float, :integer, :json, :string, :text, :time, :timestamp, :virtual]

    Model = Struct.new(:class_name, :table_name, :source, :schema, keyword_init: true)
    Column = Struct.new(:name, :type, :definition, :source, keyword_init: true)

    def self.schema(path)
      ast = Fast.ast(File.read(path))

      content = Fast.search('(block (send (const (const nil :ActiveRecord) :Schema) :define) _ $_)', ast).last.first
      Fast.search('(block (send nil :create_table (str $_)) _ _)', content)
          .each_slice(2).to_h { |t, name| [name, t] }
    end

    def self.model(ast)
      Fast.search('(class $_ {(const nil :ApplicationRecord) (const (const nil :ActiveRecord) :Base)})', ast).each_slice(2)
          .map { |node, name|
            class_name = Unparser.unparse(name.first)
            schema = Fast.search('$(block (send nil :the_schema_is) _ ...', node)&.last
            Model.new(
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
          .first
    end

    def self.columns(ast)
      content = ast.type == :begin ? ast.children : [ast]
      content.map { |node|
        # TODO: Only if name in COLUMN_TYPES, otherwise it could be something like t.index
        # FIXME: Of course it should be easier to say "optional additional params"
        if (type, name, defs = Fast.match?('(send {(send nil t) (lvar t)} $_ (str $_) $...', node))
          Column.new(name: name, type: type, definition: defs, source: node)
        elsif (type, name = Fast.match?('(send {(send nil t) (lvar t)} $_ (str $_)', node))
          Column.new(name: name, type: type, source: node)
        end
      }.compact
    end
  end
end
