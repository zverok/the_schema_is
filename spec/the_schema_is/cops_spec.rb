# frozen_string_literal: true

RSpec.describe TheSchemaIs, :config do
  subject(:cop) { described_class.new(config) }

  let(:cop_config) { real_config.transform_keys(&:to_s) }
  let(:real_config) { {} }

  # FIXME: Better to pass it to cop as config "where is schema.rb"?..
  let(:target_dir) { File.expand_path('../fixtures/base', __dir__) }

  # TODO: Or just use FakeFS to easier show it the schema?..
  around { |example|
    Dir.chdir(target_dir) { example.run }
  }

  shared_examples 'autocorrect' do |from, to|
    subject { autocorrect_source(from) }

    it { is_expected.to eq to }
  end

  context 'when schema.rb can not be found'

  describe TheSchemaIs::Presence do
    specify {
      expect_no_offenses(<<~RUBY)
        class Comment
        end
      RUBY
    }

    specify {
      expect_offense(<<~RUBY)
        class Comment < ApplicationRecord
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ The schema is not specified in the model (use the_schema_is statement)
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

    context 'with different schema' do
      let(:real_config) { {Schema: 'db/schema2.rb'} }

      specify {
        expect_no_offenses(<<~RUBY)
          class Dog < ApplicationRecord
            the_schema_is do
              t.string "name"
            end
          end
        RUBY
      }

      specify {
        expect_offense(<<~RUBY)
          class Comment < ApplicationRecord
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Table "comments" is not defined in db/schema2.rb

            the_schema_is do
              t.string "name"
            end
          end
        RUBY
      }
    end

    context 'with different base class' do
      let(:real_config) { {BaseClass: ['Base']} }

      specify {
        expect_no_offenses(<<~RUBY)
          class Comment < ApplicationRecord
          end
        RUBY
      }

      specify {
        expect_offense(<<~RUBY)
          class Comment < Base
          ^^^^^^^^^^^^^^^^^^^^ The schema is not specified in the model (use the_schema_is statement)
          end
        RUBY
      }
    end

    context 'with table prefix' do
      let(:real_config) { {TablePrefix: 'prefixed_'} }

      specify {
        expect_no_offenses(<<~RUBY)
          class Tag < ApplicationRecord
            the_schema_is do
              t.string "text"
            end
          end
        RUBY
      }

      specify {
        expect_offense(<<~RUBY)
          class Comment < ApplicationRecord
          ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Table "prefixed_comments" is not defined in db/schema.rb
          end
        RUBY
      }
    end

    it_behaves_like 'autocorrect', <<~SRC_RUBY,
      class Comment < ApplicationRecord
      end
    SRC_RUBY
    <<~DST_RUBY
      class Comment < ApplicationRecord
        the_schema_is(:comments) do |t|
          t.text     "body"
          t.integer  "user_id"
          t.integer  "article_id"
          t.datetime "created_at", null: false
          t.datetime "updated_at", null: false
        end

      end
    DST_RUBY
  end

  describe TheSchemaIs::MissingColumn do
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

  describe TheSchemaIs::UnknownColumn do
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

  describe TheSchemaIs::WrongColumnDefinition do
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
