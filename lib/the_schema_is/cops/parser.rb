# frozen_string_literal: true

require 'active_support/inflector'

module TheSchemaIs
  module Cops
    module Parser
      using NodeRefinements

      # See https://github.com/rails/rails/blob/f33d52c95217212cbacc8d5e44b5a8e3cdc6f5b3/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb#L217
      # TODO: numeric is just an alias for decimal
      # TODO: different adapters can add another types
      # https://edgeguides.rubyonrails.org/active_record_postgresql.html
      STANDARD_COLUMN_TYPES = %i[bigint binary boolean date datetime decimal numeric
                                 float integer json string text time timestamp virtual].freeze
      POSTGRES_COLUMN_TYPES = %i[jsonb inet cidr macaddr hstore uuid].freeze

      COLUMN_DEFS = (STANDARD_COLUMN_TYPES + POSTGRES_COLUMN_TYPES + %i[column]).freeze

      Model = Struct.new(:class_name, :table_name, :source, :schema, keyword_init: true)

      Column = Struct.new(:name, :type, :definition, :source, keyword_init: true) do
        def definition_source
          return unless definition

          eval('{' + definition.loc.expression.source + '}') # rubocop:disable Security/Eval
        end
      end

      def self.schema(path)
        ast = Fast.ast(File.read(path))

        content = Fast.search(
          '(block (send (const (const nil :ActiveRecord) :Schema) :define) _ $_)',
          ast
        ).last.first
        Fast.search('(block (send nil :create_table (str $_)) _ _)', content)
            .each_slice(2).to_h { |t, name| [Array(name).first, t] } # FIXME: Why it sometimes makes arrays, and sometimes not?..
      end

      def self.model(ast, base_classes: %w[ActiveRecord::Base ApplicationRecord], table_prefix: nil)
        base = base_classes_query(base_classes)
        ast.ffast("(class $_ #{base})").each_slice(2)
           .map { |node, name| node2model(name, node, table_prefix.to_s) }
           .compact
           .first
      end

      def self.node2model(name_node, definition_node, table_prefix)
        return if definition_node.ffast('(send self abstract_class= true)').any?

        # If all children are classes/modules -- model is here only as a namespace, shouldn't be
        # parsed/have the_schema_is
        return if definition_node
                  .children[2]&.arraify&.all? { |n| %i[class module].include?(n.type) }

        class_name = name_node.first.loc.expression.source

        schema = definition_node.ffast('$(block (send nil :the_schema_is) _ ...')&.last

        # TODO: https://api.rubyonrails.org/classes/ActiveRecord/ModelSchema/ClassMethods.html#method-i-table_name
        # * consider table_prefix/table_suffix settings
        # * also, consider engines!
        table_name = definition_node.ffast('(send self table_name= (str $_)')&.last

        Model.new(
          class_name: class_name,
          table_name: table_name ||
            table_prefix.+(ActiveSupport::Inflector.tableize(class_name)),
          source: definition_node,
          schema: schema
        )
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
          if (type, name, defs =
                node.ffast_match?('(send {(send nil t) (lvar t)} $_ (str $_) $...'))
            Column.new(name: name, type: type, definition: defs, source: node) \
              if COLUMN_DEFS.include?(type)
          elsif (type, name = Fast.match?('(send {(send nil t) (lvar t)} $_ (str $_)', node))
            Column.new(name: name, type: type, source: node) if COLUMN_DEFS.include?(type)
          end
        }.compact
      end
    end
  end
end
