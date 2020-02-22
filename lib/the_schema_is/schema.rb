module TheSchemaIs
  class Schema
    def self.parse(path)
      ast = Fast.ast(File.read(path))

      content = Fast.search('(block (send (const (const nil :ActiveRecord) :Schema) :define) _ $_)', ast).last.first
      Fast.search('(block (send nil :create_table (str $_)) _ _)', content)
          .each_slice(2).to_h { |t, name| [name, t] }
    end
  end
end
