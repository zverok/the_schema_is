RSpec.describe TheSchemaIs::Cops do
  subject(:cop) { described_class.new }

  # TODO: Or just use FakeFS to easier show it the schema?..
  around { |example|
    Dir.chdir(target_dir) { example.run }
  }

  # FIXME: Better to pass it to cop as config "where is schema.rb"?..
  let(:target_dir) { File.expand_path('../fixtures/base', __dir__) }

  shared_examples 'autocorrect' do |from, to|
    subject { autocorrect_source(from) }
    it { is_expected.to eq to }
  end

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

    specify {
      expect_offense(<<~RUBY)
        class Dog < ApplicationRecord
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Table "dogs" is not defined in db/schema.rb

          the_schema_is do
            t.string "name"
          end
        end
      RUBY
    }

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
      class Comment < ApplicationRecord
      end
    SRC_RUBY
    <<~DST_RUBY
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

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
      class Comment < ApplicationRecord
        the_schema_is do |t|
          t.text     "body"
          t.integer  "user_id"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end
      end
    SRC_RUBY
    <<~DST_RUBY
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

    # First column
    it_behaves_like 'autocorrect', <<~SRC_RUBY,
      class Comment < ApplicationRecord
        the_schema_is do |t|
          t.integer  "user_id"
          t.integer  "article_id"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end
      end
    SRC_RUBY
    <<~DST_RUBY
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

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
      class Comment < ApplicationRecord
        the_schema_is do |t|
          # Comments and spaces are important
          t.integer  "user_id"
          t.integer  "article_id"

          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end
      end
    SRC_RUBY
    <<~DST_RUBY
      class Comment < ApplicationRecord
        the_schema_is do |t|
          t.text     "body"
          # Comments and spaces are important
          t.integer  "user_id"
          t.integer  "article_id"

          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end
      end
    DST_RUBY

    # TODO: Several columns, including subsequent ones!
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

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.integer  "owner_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
          end
        end
    SRC_RUBY
    <<~DST_RUBY
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

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.integer  "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at", null: false
            t.integer  "owner_id"
          end
        end
    SRC_RUBY
    <<~DST_RUBY
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

  describe TheSchemaIs::Cops::WrongColumnDefinition do
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
            ^^^^^^^^^^^^^^^^^^^^^^ Wrong column definition: expected `t.integer  "article_id"`
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
            t.datetime "created_at"
            ^^^^^^^^^^^^^^^^^^^^^^^ Wrong column definition: expected `t.datetime "created_at", null: false`
            t.datetime "updated_at", null: false
          end
        end
      RUBY
    }

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
        class Comment < ApplicationRecord
          the_schema_is do |t|
            t.text     "body"
            t.integer  "user_id"
            t.string   "article_id"
            t.datetime "created_at", null: false
            t.datetime "updated_at"
          end
        end
    SRC_RUBY
    <<~DST_RUBY
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
