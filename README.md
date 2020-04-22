# The schema is ...

## What is it

`the-schema-is` is a model schema annotation DSL in ActiveSupport.

### Why annotate?

**What attributes objects of this class have** (which are the columns in ActiveRecord model) is part of class' public interface. It _should_ be part of what I can _read immediately_ when working with the class. "It is drawn automatically from DB" is kinda clever, but it _does not_ helps to read the code. "Auto-deduction from DB" could be used to compare actual table content's to definition in Ruby, but **not** to skip the definition.

> Fun fact: most of other languages' ORM have chosen "explictly list attributes in the model" approach, for some reason! For example, Python's [Django](https://docs.djangoproject.com/en/3.0/topics/db/models/#quick-example), Elixir's [Ecto](https://hexdocs.pm/phoenix/ecto.html#the-schema), Go's [Beego](https://beego.me/docs/mvc/model/overview.md#quickstart) and [Gorm](https://gorm.io/docs/#Quick-Start), Rust's [Diesel](https://github.com/diesel-rs/diesel/blob/v1.3.0/examples/postgres/getting_started_step_1/src/models.rs), most of popular [NodeJS's options](https://www.codediesel.com/javascript/nodejs-mysql-orms/), and PHP's [Symphony](https://symfony.com/doc/current/doctrine.html#creating-an-entity-class) (but, to be honest, not [Laravel](https://laravel.com/docs/6.x/eloquent#eloquent-model-conventions)).

### Well then, why not [annotate](https://github.com/ctran/annotate_models)?

Annotate gem provides very powerful and configurable CLI/rake task which allows to add to your model (and factory/route/spec) files comment looking like...

```ruby
# == Schema Information
#
# Table name: users
#
#  id                             :integer          not null, primary key
#  email                          :string           default(""), not null
#  encrypted_password             :string           default(""), not null
#  last_sign_in_at                :datetime
#  last_sign_in_ip                :inet
#  created_at                     :datetime         not null
#  updated_at                     :datetime         not null
# ....
```

It kinda achieves the goal, but in our experience, it also brings some problems:

* annotation regeneration is disruptive, just replacing the whole block with a new one, which produces lot of "false changes" (e.g. one field with a bit longer name was added → spacing of all fields were changed);
* if on different developer's machines column order or defaults is different on dev. DB, annotate also decides to rewrite all the annotations, sometimes adding tens files "changed" to PR;
* regeneration makes it hard to use schema annotation for commenting/explaining some fields: because regeneration will lose them, and because comments-between-comments will be hard to distinguish;
* the syntax of annotations is kinda ad-hoc, which makes it harder to add them by hand, so regeneration becomes the _only_ way to add them.

### So, how your approach is different?..

`the-schema-is` allows you to do this:

```ruby
class User < ApplicationRecord
  the_schema_is "users" do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "last_sign_in_at"
    t.inet "last_sign_in_ip"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    # ...
  end
end
```

Idea is, it is _exactly_ the same DSL that `db/schema.rb` uses, so:

* it can be just copied from there (or written by hands in usual migration syntax);
* it is _code_, which can be supplemented with _comments_ explaining what some column does or why the defaults are this way (and structure with sorting and extra empty lines).

So, in reality, your annotation may look like this:

```ruby
class User < ApplicationRecord
  the_schema_is "users", id: :serial, force: :cascade do |t|
    t.string "email", default: "", null: false
    # We use RSA encryption currently.
    t.string "encrypted_password", default: "", null: false

    t.inet "last_sign_in_ip" # FIXME: Legacy, we don't use it anymore because GDPR

    t.datetime "last_sign_in_at"

    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    # ...
  end
end
```

Now, `the-schema-is` gem consists of this DSL and _custom [Rubocop](https://www.rubocop.org/) cops_ which check correspondence of this DSL in model classes to your `db/schema.rb` (and can automatically fix discrepancies found).

Using existing Rubocop's infrastructure brings several great benefits:

* you can include check "if all annotations are actual" in your CI/pre-commit hooks easily;
* you can preview problems found, and then fix them automatically (with `rubocop -a`) or manually however you see suitable;
* the changes made with auto-fix is very local (just add/remove/change line about relevant column), so your custom structuring (separating groups of related columns with empty lines) and comments will be preserved;
* rubocop is easy to run on some sub-folder, or one file, or files corresponding to some pattern; or exclude permanently for some file or folder.

### But what the block itself does?

Nothing.

**Ugh... What?**

That's just how it is (at least for now) ¯\\\_(ツ)\_/¯

The block isn't even evaluated at all (so potentially can contain any code, and only Rubocop's cop will complain). Potentially, it _can_ do some useful things (like, on app run in development environment compare scheme of the real DB with declarations in class), but for now, it is just noop declarative schema copy-paste.

## Usage

1. Add to your Gemfile `gem 'the-schema-is'` and run `bundle install`.
2. Add to your `.rubocop.yml` this:
  ```yaml
  require:
    - the-schema-is/cops
  ```
3. Run `rubocop` and see what it now says about your models.
4. Now you can add schema definitions manually, or allow `rubocop --auto-fix` to do its job! (NB: you can always use `rubocop --auto-fix --only TheSchemaIs` to auto-fix ONLY this schema thing)

The cop supports some configuration, you can see the current one with `rubocop --show-cops TheSchemaIs/Presence`.

To make reporting cleaner, all cops are split into:
* `Presence`
* `MissingColumn`
* `UnknownColumn`
* `WrongColumnDefinition`

It is not advisable to selectively turn them off, but you may know better (for example, some may experiment with leaving in models just `t.<type> '<name>'` without details about defaults and limit, and therefore turn off `WrongColumnDefinition`), all of it is pretty experimental!

## Setting

All cops support the same 3 settings (so it makes sense to set them for the whole namespace when you need):

* `TablePrefix` to guess which table corresponds to model (by default no prefix)
* `Schema` to set path to schema (by default `db/schema.rb`)
* `BaseClass` to guess what is a model (by default `ApplicationRecord` and `ActiveRecord::Base`)

TODO: Examples

Note that Rubocop allows per-folder settings out of the box, which allows TheSchemaIs even at tender version of 0.0.1, support complicated configurations with multiple databases and engines.

TODO: Explain

## Some Q&A

* It doesn't check the actual DB?
* What if I don't use Rubocop?
* How can I annotate my fabrics, model specs, routes, controllers, ... (which `annotate` allows)?
* Rubocop is unhappy and ...
  Metrics/BlockLength:

-----
below this line is drafts/rough thouhts.

Cop checks (TBD):
* schema present
* there is a table in db/schema.rb
* each column corresponds
* indexes correspond (tunable)
* other stuff correspond (tunable)
* setting: names symbols or strings
* content / style, duplicates, allowed extra info (like indexes, "allowed but ignored"), enforced extra info, disallowed (nothing except col.defs)
* multiple db/schema, detect which is which
* engines
