RSpec.describe TheSchemaIs::Parser do
  describe '.model' do
    shared_examples 'model extractor' do |code, attrs|
      subject { described_class.model(Fast.ast(code)) }

      if attrs.nil?
        it { is_expected.to be_nil }
      else
        it { is_expected.to have_attributes(attrs) }
      end
    end

    it_behaves_like 'model extractor',
      <<~RUBY, nil
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
        self.table_name = 'authors'
      end
      RUBY
      {class_name: 'User', table_name: 'authors', schema: nil}

    it_behaves_like 'model extractor',
      <<~RUBY,
      class User < ActiveRecord::Base
        the_schema_is do |t|
          t.string "name"
        end
      end
      RUBY
      {class_name: 'User', table_name: 'users', schema: Astrolabe::Node}

    it_behaves_like 'model extractor',
      <<~RUBY,
      class User < ApplicationRecord
        the_schema_is do |t|
          t.string "name"
        end
      end
      RUBY
      {class_name: 'User', table_name: 'users', schema: Astrolabe::Node}
  end

  describe '.schema' do
    subject { described_class.schema(path) }

    let(:path) { 'spec/fixtures/base/db/schema.rb' }

    it { is_expected.to be_a(Hash) }
    its(:keys) { is_expected.to start_with('articles', 'comments', 'favorites') }
    its(:values) { is_expected.to all be_a Astrolabe::Node }
  end

  describe '.columns' do
    shared_examples 'column extractor' do |code, attrs|
      subject { described_class.columns(Fast.ast(code)) }

      it { is_expected.to contain_exactly(*attrs.map { |a| have_attributes(a) }) }
    end

    it_behaves_like 'column extractor',
      <<~RUBY,
        t.string "name"
        t.integer "user_id"
      RUBY
      [{name: 'name', type: :string}, {name: 'user_id', type: :integer}]

    it_behaves_like 'column extractor',
      <<~RUBY,
        t.datetime "created_at", null: false
      RUBY
      [{name: 'created_at', definition_source: {null: false}}]

    it_behaves_like 'column extractor',
      <<~RUBY,
        t.datetime "created_at"
        t.index "created_at"
      RUBY
      [{name: 'created_at'}]
  end
end
