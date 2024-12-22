# frozen_string_literal: true

require 'memery'
require 'rubocop'
require 'backports/latest'

require_relative 'cops/node_util'
require_relative 'cops/inject'

TheSchemaIs::Cops::Inject.defaults!

require_relative 'cops/parser'

module TheSchemaIs
  using Cops::NodeRefinements

  module Cops
    class << self
      include Memery

      memoize def fetch_schema(path, remove_definition_attrs: [])
        Cops::Parser.schema(path, remove_definition_attrs: remove_definition_attrs)
      end
    end
  end

  module Common
    include Memery

    def self.included(cls)
      cls.define_singleton_method(:badge) do
        RuboCop::Cop::Badge.for("TheSchemaIs::#{name.split('::').last}")
      end
      super
    end

    def on_class(node)
      @model = Cops::Parser.model(node,
                                  base_classes: cop_config.fetch('BaseClass'),
                                  table_prefix: cop_config['TablePrefix']) or return

      register_offense(node)
    end

    # We need this method to tell Rubocop that EVEN if app/models/user.rb haven't changed, and
    # .rubocop.yml haven't changed, we STILL may need to rerun the cop if schema.rb have changed.
    def external_dependency_checksum
      return unless schema_path

      Digest::SHA1.hexdigest(File.read(schema_path))
    end

    private

    attr_reader :model

    def register_offense(node)
      fail NotImplementedError
    end

    memoize def schema_path
      cop_config.fetch('Schema')
    end

    memoize def schema
      attrs_to_remove = cop_config['RemoveDefinitions']&.map(&:to_sym) || []
      # It is OK if it returns Nil, just will be handled by "schema is absent" cop
      Cops.fetch_schema(schema_path, remove_definition_attrs: attrs_to_remove)[model.table_name]
    end

    memoize def model_columns
      statements = model.schema.ast_search('(block (send nil? :the_schema_is _?) _ $...)')
                        .last.last

      Cops::Parser.columns(statements).to_h { |col| [col.name, col] }
    end

    memoize def schema_columns
      Cops::Parser.columns(schema).to_h { |col| [col.name, col] }
    end
  end

  class Presence < RuboCop::Cop::Base
    include Common
    extend RuboCop::Cop::AutoCorrector

    MSG_NO_MODEL_SCHEMA = 'The schema is not specified in the model (use the_schema_is statement)'
    MSG_NO_DB_SCHEMA = 'Table "%s" is not defined in %s'

    private

    def register_offense(node)
      schema.nil? and
        add_offense(model.source, message: MSG_NO_DB_SCHEMA % [model.table_name, schema_path])

      model.schema.nil? and add_offense(model.source, message: MSG_NO_MODEL_SCHEMA) do |corrector|
        indent = node.loc.expression.column + 2
        code = [
          "the_schema_is #{model.table_name.to_s.inspect} do |t|",
          *schema_columns.map { |_, col| "  #{col.source.loc.expression.source}" },
          'end'
        ].map { |s| ' ' * indent + s }.join("\n").then { |s| "\n#{s}\n" }

        # in "class User < ActiveRecord::Base" -- second child is "ActiveRecord::Base"
        corrector.insert_after(node.children[1].loc.expression, code)
      end
    end
  end

  class WrongTableName < RuboCop::Cop::Base
    include Common
    extend RuboCop::Cop::AutoCorrector

    MSG_WRONG_TABLE_NAME = 'The real table name should be %p'
    MSG_NO_TABLE_NAME = 'Table name is not specified'

    private

    def register_offense(_node)
      return if model.schema.nil? || schema.nil?

      pp

      if model.table_name_node.nil?
        add_offense(model.schema, message: MSG_NO_TABLE_NAME) do |corrector|
          corrector.insert_after(model.schema.children[0].loc.expression, " #{model.table_name.to_s.inspect}")
        end
      elsif model.table_name_node.children[0] != model.table_name
        add_offense(model.table_name_node,
                    message: MSG_WRONG_TABLE_NAME % model.table_name) do |corrector|
          corrector.replace(model.table_name_node.loc.expression, model.table_name.to_s.inspect)
        end
      end
    end
  end

  class MissingColumn < RuboCop::Cop::Base
    include Common
    extend RuboCop::Cop::AutoCorrector

    MSG = 'Column "%s" definition is missing'

    private

    def register_offense(_node)
      return if model.schema.nil? || schema.nil?

      missing_columns.each do |name, col|
        add_offense(model.schema, message: MSG % col.name) do |corrector|
          insert_column(corrector, name, col)
        end
      end
    end

    def insert_column(corrector, name, col)
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
    end

    def missing_columns
      schema_columns.reject { |name,| model_columns.keys.include?(name) }
    end
  end

  class UnknownColumn < RuboCop::Cop::Base
    include Common
    extend RuboCop::Cop::AutoCorrector

    MSG = 'Uknown column "%s"'

    private

    def register_offense(_node)
      return if model.schema.nil? || schema.nil?

      extra_columns.each_value do |col|
        add_offense(col.source, message: MSG % col.name) do |corrector|
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

    def extra_columns
      model_columns.reject { |name,| schema_columns.keys.include?(name) }
    end
  end

  class WrongColumnDefinition < RuboCop::Cop::Base
    include Common
    extend RuboCop::Cop::AutoCorrector

    MSG = 'Wrong column definition: expected `%s`'

    private

    def register_offense(_node)
      return if model.schema.nil? || schema.nil?

      wrong_columns
        .each do |mcol, scol|
          add_offense(mcol.source, message: MSG % scol.source.loc.expression.source) do |corrector|
            corrector.replace(mcol.source.loc.expression, scol.source.loc.expression.source)
          end
        end
    end

    def wrong_columns
      model_columns
        .map { |name, col| [col, schema_columns[name]] }
        .reject { |mcol, scol|
          # When column is not in schema, we shouldn't try to check it: UnknownColumn cop will
          # handle.
          !scol || mcol.type == scol.type && mcol.definition_source == scol.definition_source
        }
    end
  end
end
