RSpec.describe TheSchemaIs::Model do
  shared_examples 'model extractor' do |code, *models|
    subject { described_class.parse(code) }

    it {
      is_expected.to contain_exactly(*models.map { |definition| have_attributes(definition) })
    }
  end

  describe '.parse' do
    it_behaves_like 'model extractor',
      <<~RUBY
      class User
      end
      RUBY

    it_behaves_like 'model extractor',
      <<~RUBY,
      class User < ActiveRecord::Base
      end
      RUBY
      {class_name: 'User', table_name: 'users', schema: nil}

    it_behaves_like 'model extractor',
      <<~RUBY,
      class User < ActiveRecord::Base
        the_schema_is do |t|
          t.string "name"
        end
      end
      RUBY
      {class_name: 'User', table_name: 'users', schema: Astrolabe::Node}
  end
end
