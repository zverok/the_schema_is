# frozen_string_literal: true

require 'active_support'

module TheSchemaIs
  module DSL
    # Just a no-op!
    def the_schema_is(*); end
  end
end

ActiveSupport.on_load(:active_record) do
  extend TheSchemaIs::DSL
end
