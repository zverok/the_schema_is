RSpec.describe TheSchemaIs::Differ do
  D = described_class::D

  shared_examples 'table diff' do |left, right, diff|
    let(:left_ast) { Fast.ast(left) }
    let(:right_ast) { Fast.ast(right) }

    subject { described_class.new(left_ast, right_ast).call }

    it { is_expected.to eq diff }
  end

  # Same content
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    []

  # Same content, different order
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.string "email"
      t.string "name"
    RUBY
    []

  # Extra column
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.string "name"
      t.string "email"
      t.integer "age"
    RUBY
    [
      D.insert(name: 'age', definition: {type: :integer})
    ]

  # Lacking column
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.string "name"
    RUBY
    [
      D.remove(name: 'email', definition: {type: :string})
    ]

  # Different column type
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.text "name"
      t.string "email"
    RUBY
    [
      D.change(name: 'name', from: {type: :string}, to: {type: :text})
    ]

  # Different column details
  it_behaves_like 'table diff',
    <<~RUBY,
      t.string "name"
      t.string "email"
    RUBY
    <<~RUBY,
      t.string "name"
      t.string "email", null: false
    RUBY
    [
      D.change(name: 'email', from: {type: :string}, to: {type: :string, null: false})
    ]
end
