# frozen_string_literal: true

require 'memoist'
require 'rubocop'
require 'fast'
require 'backports/latest'

require_relative 'cops/node_util'
require_relative 'cops/inject'

TheSchemaIs::Cops::Inject.defaults!

require_relative 'cops/parser'

module TheSchemaIs
  using Cops::NodeRefinements

  module Common
    extend Memoist

    def self.included(cls)
      cls.define_singleton_method(:badge) {
        RuboCop::Cop::Badge.for("TheSchemaIs::#{name.split('::').last}")
      }
    end

    def on_class(node)
      @model = Cops::Parser.model(node,
                                  base_classes: cop_config.fetch('BaseClass'),
                                  table_prefix: cop_config['TablePrefix']) or return

      validate
    end

    private

    attr_reader :model

    def validate
      fail NotImplementedError
    end

    memoize def schema_path
      cop_config.fetch('Schema')
    end

    memoize def schema
      Cops::Parser.schema(schema_path)[model.table_name]
    end

    memoize def model_columns
      statements = model.schema.ffast('(block (send nil :the_schema_is) (args) $...)').last.last

      Cops::Parser.columns(statements).to_h { |col| [col.name, col] }
    end

    memoize def schema_columns
      statements = schema.ffast('(block (send nil :create_table) (args) $...)').last.last

      Cops::Parser.columns(statements).to_h { |col| [col.name, col] }
    end
  end

  class Presence < RuboCop::Cop::Cop
    include Common

    MSG_NO_MODEL_SCHEMA = 'The schema is not defined for the model'
    MSG_NO_DB_SCHEMA = 'Table "%s" is not defined in %s'

    def autocorrect(node)
      return unless schema

      statements = schema.ffast('(block (send nil :create_table) (args) $...)').last.last.arraify

      lambda do |corrector|
        indent = node.loc.expression.column + 2
        code = [
          'the_schema_is do |t|',
          *statements.map { |s| "  #{s.loc.expression.source}" },
          'end'
        ].map { |s| ' ' * indent + s }.join("\n").then { |s| "\n#{s}\n" }

        # in "class User < ActiveRecord::Base" -- second child is "ActiveRecord::Base"
        corrector.insert_after(node.children[1].loc.expression, code)
      end
    end

    private

    def validate
      schema.nil? and
        add_offense(model.source, message: MSG_NO_DB_SCHEMA % [model.table_name, schema_path])
      model.schema.nil? and add_offense(model.source, message: MSG_NO_MODEL_SCHEMA)
    end
  end

  class MissingColumn < RuboCop::Cop::Cop
    include Common

    MSG = 'Column "%s" definition is missing'

    def autocorrect(_node)
      lambda do |corrector|
        missing_columns.each { |name, col|
          prev_statement = model_columns
                           .slice(*schema_columns.keys[0...schema_columns.keys.index(name)])
                           .values.last&.source
          if prev_statement
            indent = prev_statement.loc.expression.column
            corrector.insert_after(
              prev_statement.loc.expression,
              "\n#{' ' * indent}#{col.source.loc.expression.source}"
            )
          else
            indent = model.schema.loc.expression.column + 2
            corrector.insert_after(
              # of "the_schema_is do |t|" -- children[1] is "|t|""
              model.schema.children[1].loc.expression,
              "\n#{' ' * indent}#{col.source.loc.expression.source}"
            )
          end
        }
      end
    end

    private

    def validate
      return if model.schema.nil? || schema.nil?

      missing_columns.each do |_, col|
        add_offense(model.schema, message: MSG % col.name)
      end
    end

    def missing_columns
      schema_columns.reject { |name,| model_columns.keys.include?(name) }
    end
  end

  class UnknownColumn < RuboCop::Cop::Cop
    include Common

    MSG = 'Uknown column "%s"'

    def autocorrect(_node)
      lambda do |corrector|
        extra_columns.each do |_, col|
          src_range = col.source.loc.expression
          end_pos = col.source.next_sibling.then { |n|
            n ? n.loc.expression.begin_pos - 2 : col.source.find_parent(:block).loc.end.begin_pos
          }
          range =
            ::Parser::Source::Range.new(src_range.source_buffer, src_range.begin_pos - 2, end_pos)
          corrector.remove(range)
        end
      end
    end

    private

    def validate
      return if model.schema.nil? || schema.nil?

      extra_columns.each do |_, col|
        add_offense(col.source, message: MSG % col.name)
      end
    end

    def extra_columns
      model_columns.reject { |name,| schema_columns.keys.include?(name) }
    end
  end

  class WrongColumnDefinition < RuboCop::Cop::Cop
    include Common

    MSG = 'Wrong column definition: expected `%s`'

    def autocorrect(_node)
      lambda do |corrector|
        wrong_columns.each do |mcol, scol|
          corrector.replace(mcol.source.loc.expression, scol.source.loc.expression.source)
        end
      end
    end

    private

    def validate
      return if model.schema.nil? || schema.nil?

      wrong_columns
        .each do |mcol, scol|
          add_offense(mcol.source, message: MSG % scol.source.loc.expression.source)
        end
    end

    def wrong_columns
      model_columns
        .map { |name, col| [col, schema_columns[name]] }
        .reject { |mcol, scol|
          mcol.type == scol.type && mcol.definition_source == scol.definition_source
        }
    end
  end
end
