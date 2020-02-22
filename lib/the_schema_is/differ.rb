module TheSchemaIs
  class Differ
    # https://api.rubyonrails.org/classes/ActiveRecord/ConnectionAdapters/TableDefinition.html

    # See https://github.com/rails/rails/blob/f33d52c95217212cbacc8d5e44b5a8e3cdc6f5b3/activerecord/lib/active_record/connection_adapters/abstract/schema_definitions.rb#L217
    # TODO: numeric is just an alias for decimal
    COLUMN_TYPES = [:bigint, :binary, :boolean, :date, :datetime, :decimal, :numeric,
          :float, :integer, :json, :string, :text, :time, :timestamp, :virtual]

    class Column < Struct.new(:name, :definition)
      def initialize(name, **definitions)
        super(name, definitions)
      end
    end
    Definition = Struct.new(:columns, keyword_init: true)

    class D
      KINDS = %i[insert remove change]

      KINDS.each do |k|
        define_singleton_method(k) { |**definition| new(k, **definition) }
      end

      attr_reader :kind, :definition

      def initialize(kind, **definition)
        @kind = kind
        @definition = definition.compact
      end

      def inspect
        "#<D.#{kind}(#{definition})>"
      end

      alias to_s inspect

      def ==(other)
        other.is_a?(D) && other.kind == kind && other.definition == definition
      end
    end

    def initialize(left, right)
      @left = left
      @right = right
    end

    def call
      left_def = parse_definition(@left)
      right_def = parse_definition(@right)

      left_names = left_def.columns.map(&:name)
      right_names = right_def.columns.map(&:name)
      res = []
      left_def.columns.reject { |c| right_names.include?(c.name) }.each do |col|
        res << D.remove(col.to_h)
      end
      right_def.columns.reject { |c| left_names.include?(c.name) }.each do |col|
        res << D.insert(col.to_h)
      end

      (left_names & right_names).each do |name|
        leftcol = left_def.columns.find { |c| c.name == name }
        rightcol = right_def.columns.find { |c| c.name == name }
        unless leftcol.definition == rightcol.definition
          res << D.change(name: name, from: leftcol.definition, to: rightcol.definition)
        end
      end

      res
    end

    # TODO: don't hardcode :t as a table name :)
    def parse_definition(ast)
      content = ast.type == :begin ? ast.children : [ast]
      columns = []
      content.each do |node|
        # FIXME: Of course it should be easier to say "optional additional params"
        if (type, name, defs = Fast.match?('(send (send nil :t) $_ (str $_) $...', node))
          defs = eval(Unparser.unparse(defs))
          columns << Column.new(name, type: type, **defs)
        elsif (type, name = Fast.match?('(send (send nil :t) $_ (str $_)', node))
          columns << Column.new(name, type: type)
        end
      end
      Definition.new(columns: columns)
    end
  end
end
