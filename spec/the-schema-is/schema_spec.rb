RSpec.describe TheSchemaIs::Schema do
  describe '.parse' do
    subject { described_class.parse(path) }

    let(:path) { 'spec/fixtures/base/db/schema.rb' }

    it { is_expected.to be_a(Hash) }
    its(:keys) { is_expected.to start_with('articles', 'comments', 'favorites') }
    its(:values) { is_expected.to all be_a Astrolabe::Node }
  end
end
