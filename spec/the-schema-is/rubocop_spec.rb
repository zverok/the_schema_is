RSpec.xdescribe TheSchemaIs::Cop::Content do
  subject(:cop) { described_class.new }

  # TODO: Or just use FakeFS to easier show it the schema?..
  before { Dir.chdir current_dir }

  # FIXME: Better to pass it to cop as config "where is schema.rb"?..
  let(:current_dir) { File.expand_path('../fixtures/base', __dir__) }

  context 'when schema.rb can not be found'
  context 'when class is not AR model' do
    specify {
      expect_no_offenses(<<~RUBY)
        class A
        end
      RUBY
    }
  end
  context 'when no schema is set in model' do
    specify {
      expect_offense(<<~RUBY)
        class A < ApplicationRecord
        ^^^^^^^ The schema is not defined for the model
        end
      RUBY
    }
  end

  context 'when schema in model same as in schema.rb'
  context 'when differences are cosmetic'
  context 'when definitions list different'
  context 'when definitions details different'

  describe 'guess table name' do
    # inflections vs explicit setting
    # namespaces/different DBs/complicated settings...
  end

  describe 'choosing and ignoring what classes to inspect' do
    # Not break with:
    # * nested classes
    # * classes in namespaces
    # * classes from different DBs
    # * non-model classes in app/models/
    # * totally custom layout of app (settings? or just detect all AR::Base/AppRecord descendants)
    # * complicated inheritance (ThisModel < BaseModel < VeryBaseModel < GenericModel < ApplicationRecord < AR::Base)
    # ^^^ the last two seems impossible without loading the whole app...
    # ^ v0: just ignore base-less classes, take everything from models, the rest could be set in cop
  end
end
