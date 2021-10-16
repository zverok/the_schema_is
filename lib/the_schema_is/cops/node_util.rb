# frozen_string_literal: true

require 'singleton'

module TheSchemaIs
  module Cops
    # This module mitigates usage of RuboCop's NodePattern in a more flexible manner. NodePattern
    # (targeting RuboCop's goals) was only available as a metaprogramming macro, requiring to
    # `def_node_search :some_method, pattern` before the pattern can be used, while we wanted to
    # just do `ast.ast_search(some_pattern)`; so this method defines a method for each used pattern
    # on the fly and hides this discrepancy. Used by NodeRefinements (mixed into parser's node) to
    # provide `Node#ast_search` and `Node#ast_match`.
    class Patterns
      include Singleton
      extend RuboCop::AST::NodePattern::Macros

      class << self
        extend Memoist

        def search(pattern, node)
          search_methods[pattern].then { |m| instance.send(m, node) }
        end

        def match(pattern, node)
          match_methods[pattern].then { |m| instance.send(m, node) }
        end

        private

        memoize def search_methods
          Hash.new { |h, pattern|
            method_name = "search_#{h.size}"
            def_node_search method_name, pattern
            h[pattern] = method_name
          }
        end

        memoize def match_methods
          Hash.new { |h, pattern|
            method_name = "match_#{h.size}"
            def_node_search method_name, pattern
            h[pattern] = method_name
          }
        end
      end
    end

    module NodeRefinements
      refine ::Parser::AST::Node do
        def ast_search(expr)
          Patterns.search(expr, self).to_a
        end

        def ast_match(expr)
          Patterns.match(expr, self).to_a.first
        end

        def arraify
          type == :begin ? children : [self]
        end

        def next_sibling
          return unless parent

          parent.children.index(self).then { |i| parent.children[i + 1] }
        end

        def find_parent(type)
          Enumerator.produce(parent, &:parent).find { |n| n && n.type == type }
        end
      end
    end
  end
end
