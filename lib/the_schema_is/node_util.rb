module TheSchemaIs
  module NodeRefinements
    refine ::Parser::AST::Node do
      def ffast(expr)
        Fast.search(expr, self)
      end

      def ffast_match?(expr)
        Fast.match?(expr, self)
      end

      def arraify
        type == :begin ? children : [self]
      end

      def next_sibling
        return unless parent
        parent.children.index(self).then { |i| parent.children[i + 1] }
      end

      def find_parent(type)
        Enumerator.produce(parent) { |n| n.parent }.slice_after { |n| n && n.type == type }.first.last
      end
    end
  end
end
