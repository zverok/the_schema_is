require 'memoist'

module TheSchemaIs
  module Cops
    module Common
      extend Memoist

      def on_class(node)
        @model = Parser.model(node) or return

        validate
      end

      private

      attr_reader :model

      def validate
        fail NotImplementedError
      end

      memoize def schema
        # TODO: Path to schema from config
        Parser.schema('db/schema.rb')[model.table_name]
      end

      memoize def model_columns
        statements = Fast.search('(block (send nil :the_schema_is) (args) $...)', model.schema).last.last

        Parser.columns(statements).to_h { |col| [col.name, col] }
      end

      memoize def schema_columns
        statements = Fast.search('(block (send nil :create_table) (args) $...)', schema).last.last

        Parser.columns(statements).to_h { |col| [col.name, col] }
      end
    end

    class Presence < RuboCop::Cop::Cop
      include Common

      MSG = 'The schema is not defined for the model'

      private

      def validate
        add_offense(model.source) if model.schema.nil?
      end
    end

    class MissingColumn < RuboCop::Cop::Cop
      include Common

      MSG = 'Column "%s" definition is missing'

      private

      def validate
        return if model.schema.nil?

        schema_columns.reject { |name, | model_columns.keys.include?(name) }.each do |_, col|
          add_offense(model.schema, message: MSG % col.name)
        end
      end
    end

    class UnknownColumn < RuboCop::Cop::Cop
      include Common

      MSG = 'Uknown column "%s"'

      private

      def validate
        return if model.schema.nil?

        model_columns.reject { |name, | schema_columns.keys.include?(name) }.each do |_, col|
          add_offense(col.source, message: MSG % col.name)
        end
      end
    end

    class WrongColumnType < RuboCop::Cop::Cop
      include Common

      MSG = 'Wrong column type for "%s": expected %s'

      private

      def validate
        return if model.schema.nil?

        model_columns
          .map { |name, col| [col, schema_columns[name]] }
          .reject { |mcol, scol| mcol.type == scol.type }
          .each do |mcol, scol|
            add_offense(mcol.source, message: MSG % [mcol.name, scol.type])
          end
      end
    end

    class ColumnDefinitionsDiffer < RuboCop::Cop::Cop
    end
  end
end
