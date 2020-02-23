require 'active_support/inflector'

module TheSchemaIs
  module Parser
    using NodeRefinements

    # See https://github.com/rails/rails/blob/f33d52c95217212cbacc8d5e44b5a8e3cdc6f5b3/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb#L217
    # TODO: numeric is just an alias for decimal
    # TODO: different adapters can add another types (jsonb for Postgres)
    COLUMN_TYPES = [:bigint, :binary, :boolean, :date, :datetime, :decimal, :numeric,
          :float, :integer, :json, :string, :text, :time, :timestamp, :virtual] +
          [:jsonb] # Postgres

    Model = Struct.new(:class_name, :table_name, :source, :schema, keyword_init: true)
    class Column < Struct.new(:name, :type, :definition, :source, keyword_init: true)
      def definition_source
        return unless definition
        eval('{' + definition.loc.expression.source + '}')
      end
    end

    def self.schema(path)
      ast = Fast.ast(File.read(path))

      content = Fast.search('(block (send (const (const nil :ActiveRecord) :Schema) :define) _ $_)', ast).last.first
      Fast.search('(block (send nil :create_table (str $_)) _ _)', content)
          .each_slice(2).to_h { |t, name| [Array(name).first, t] } # FIXME: Why it sometimes makes arrays, and sometimes not?..
    end

    def self.model(ast, base_classes = %w[ActiveRecord::Base ApplicationRecord])
      base = base_classes_query(base_classes)
      ast.ffast("(class $_ #{base})").each_slice(2)
          .map { |node, name|
            class_name = Unparser.unparse(name.first)
            schema = node.ffast('$(block (send nil :the_schema_is) _ ...')&.last
            # TODO: https://api.rubyonrails.org/classes/ActiveRecord/ModelSchema/ClassMethods.html#method-i-table_name
            # * consider table_prefix/table_suffix settings
            # * also, consider engines!
            table_name = node.ffast('(send self $_ (str $_)').each_slice(3)
              .find { |_, meth, | meth == :table_name= } # FIXME: should be possible with Fast statement?..
              &.last
            Model.new(
              class_name: class_name,
              # TODO:
              # * search for self.table_name = ...
              # * check with namespaces and other stuff
              # * then, allow to configure in other ways
              table_name: table_name || ActiveSupport::Inflector.tableize(class_name),
              source: node,
              schema: schema
            )
          }
          .first
    end

    def self.base_classes_query(classes)
      classes
        .map { |cls| cls.split('::').inject('nil') { |res, str| "(const #{res} :#{str})" } }
        .join(' ')
        .then { |str| "{#{str}}" }
    end

    def self.columns(ast)
      ast.arraify.map { |node|
        # FIXME: Of course it should be easier to say "optional additional params"
        if (type, name, defs = Fast.match?('(send {(send nil t) (lvar t)} $_ (str $_) $...', node))
          Column.new(name: name, type: type, definition: defs, source: node) if COLUMN_TYPES.include?(type)
        elsif (type, name = Fast.match?('(send {(send nil t) (lvar t)} $_ (str $_)', node))
          Column.new(name: name, type: type, source: node) if COLUMN_TYPES.include?(type)
        end
      }.compact
    end
  end
end
