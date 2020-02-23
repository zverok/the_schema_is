RSpec.describe TheSchemaIs::Cops do
  subject(:cop) { described_class.new }

  # TODO: Or just use FakeFS to easier show it the schema?..
  around { |example|
    Dir.chdir(target_dir) { example.run }
  }

  # FIXME: Better to pass it to cop as config "where is schema.rb"?..
  let(:target_dir) { File.expand_path('../fixtures/base', __dir__) }

  context 'when schema.rb can not be found'

  describe TheSchemaIs::Cops::Presence do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment
        end
      RUBY
    }

    specify {
      expect_offense(<<~RUBY)
        class Comment < ApplicationRecord
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ The schema is not defined for the model
        end
      RUBY
    }

    describe '#autocorrect' do
      subject { method(:autocorrect_source) }

      its_call(<<~SRC_RUBY) { is_expected.to ret <<~DST_RUBY }
        class Comment < ApplicationRecord
        end
      SRC_RUBY
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end

        end
      DST_RUBY
    end
  end

  describe TheSchemaIs::Cops::MissingColumn do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }

    specify {
      expect_offense(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
          ^^^^^^^^^^^^^^^^^^^^ Column "article_id" definition is missing
            t.text     "body"
            t.integer  "user_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }
  end

  describe TheSchemaIs::Cops::UnknownColumn do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }

    specify {
      expect_offense(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.integer  "owner_id"
            ^^^^^^^^^^^^^^^^^^^^^ Uknown column "owner_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }
  end

  describe TheSchemaIs::Cops::WrongColumnType do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }

    specify {
      expect_offense(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.string  "article_id"
            ^^^^^^^^^^^^^^^^^^^^^^ Wrong column type for "article_id": expected integer
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }
  end
end

__END__

  context 'when schema in model same as in schema.rb' do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }
  end
  # context 'when differences are cosmetic'

  context 'when definitions list different' do
    context 'when there is missing column' do
      specify {
        expect_offense(<<~RUBY)
          class Comment < ApplicationRecord
            the_schema_is do |t|
            ^^^^^^^^^^^^^^^^^^^^ Column "article_id" definition is missing
              t.text     "body"
              t.integer  "user_id"
              t.datetime "created_at", null: false
              t.datetime "updated_at", null: false
            end
          end
        RUBY
      }
    end
  end

  # context 'when definitions details different'

  # describe 'guess table name' do
  #   # inflections vs explicit setting
  #   # namespaces/different DBs/complicated settings...
  # end

  # describe 'choosing and ignoring what classes to inspect' do
  #   # Not break with:
  #   # * nested classes
  #   # * classes in namespaces
  #   # * classes from different DBs
  #   # * non-model classes in app/models/
  #   # * totally custom layout of app (settings? or just detect all AR::Base/AppRecord descendants)
  #   # * complicated inheritance (ThisModel < BaseModel < VeryBaseModel < GenericModel < ApplicationRecord < AR::Base)
  #   # ^^^ the last two seems impossible without loading the whole app...
  #   # ^ v0: just ignore base-less classes, take everything from models, the rest could be set in cop
  # end
end
