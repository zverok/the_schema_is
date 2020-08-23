# The schema is ...

[![Gem Version](https://badge.fury.io/rb/the_schema_is.svg)](http://badge.fury.io/rb/the_schema_is)
![Build Status](https://github.com/zverok/the_schema_is/workflows/CI/badge.svg?branch=master)

`the_schema_is` is a model schema annotation DSL for ActiveSupport models, enforced by Rubocop. [Jump to detailed description →](#so-how-your-approach-is-different).

### Why annotate?

An important part of class' public interface is **what attributes objects of this class have**. In ActiveRecord, attributes are inferred from DB columns and only can be seen in `db/schema.rb`, which is unfortunate.

We believe it _should_ be part _immediately available_ information of class definition. "It is drawn automatically from DB" is kinda clever, but it _does not_ helps to read the code. "Auto-deduction from DB" could be used to compare actual table content's to the definition in Ruby but **not** to skip the definition.

> Fun fact: most of other languages' ORM have chosen "explictly list attributes in the model" approach, for some reason! For example, Python's [Django](https://docs.djangoproject.com/en/3.0/topics/db/models/#quick-example), Elixir's [Ecto](https://hexdocs.pm/phoenix/ecto.html#the-schema), Go's [Beego](https://beego.me/docs/mvc/model/overview.md#quickstart) and [Gorm](https://gorm.io/docs/#Quick-Start), Rust's [Diesel](https://github.com/diesel-rs/diesel/blob/v1.3.0/examples/postgres/getting_started_step_1/src/models.rs), most of popular [NodeJS's options](https://www.codediesel.com/javascript/nodejs-mysql-orms/), and PHP's [Symphony](https://symfony.com/doc/current/doctrine.html#creating-an-entity-class) (but, to be honest, not [Laravel](https://laravel.com/docs/6.x/eloquent#eloquent-model-conventions)).

### Well then, why not [annotate](https://github.com/ctran/annotate_models) gem?

Annotate gem provides a very powerful and configurable CLI/rake task which allows adding to your model (and factory/route/spec) files comment looking like...

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

* annotation **regeneration is disruptive**, just replacing the whole block with a new one, which produces a lot of "false changes" (e.g. one field with a bit longer name was added → spacing of all fields were changed);
* if on different developer's machines **column order or defaults is different** in dev. DB, annotate also decides to rewrite all the annotations, sometimes adding tens files "changed" to PR;
* regeneration makes it **hard to use schema annotation for commenting/explaining** some fields: because regeneration will lose them, and because comments-between-comments will be hard to distinguish;
* the **syntax of annotations is kinda ad-hoc**, which makes it harder to add them by hand, so regeneration becomes the _only_ way to add them.

### So, how your approach is different?..

`the_schema_is` allows you to do this:

```ruby
class User < ApplicationRecord
  the_schema_is "users" do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", null: false
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
* it is _code_, which can be supplemented with _comments_ explaining what some column does, or why the defaults are this way; it also can be structured with columns reordering and extra blank lines.

So, in reality, your annotation may look like this:

```ruby
class User < ApplicationRecord
  the_schema_is "users" do |t|
    t.string "email", default: "", null: false
    # We use RSA encryption currently.
    t.string "encrypted_password", null: false

    t.inet "last_sign_in_ip" # FIXME: Legacy, we don't use it anymore because GDPR

    t.datetime "last_sign_in_at"

    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    # ...
  end
end
```

Now, `the_schema_is` gem consists of this DSL and _custom [Rubocop](https://www.rubocop.org/) cops_ which check the correspondence of this DSL in model classes to your `db/schema.rb` (and can automatically fix discrepancies found).

Using existing Rubocop's infrastructure brings several great benefits:

* you can include checking "if all annotations are actual" in your CI/pre-commit hooks easily;
* you can preview problems found, and then fix them automatically (with `rubocop -a`) or manually however you see suitable;
* the changes made with auto-correct is very local (just add/remove/change line related to relevant column), so your custom structuring, like separating groups of related columns with empty lines and comments, will be preserved;
* rubocop is easy to run on some sub-folder or one file, or files corresponding to some pattern; or exclude permanently for some file or folder.

### But what the block itself does?

Nothing.

**Ugh... What?**

That's just how it is (at least for now) ¯\\\_(ツ)\_/¯

The block isn't even evaluated at all (so potentially can contain any code, and only Rubocop's cop will complain). In the future, it _can_ do some useful things (like, on app run in development environment compare scheme of the real DB with declarations in class), but for now, it is just noop declarative schema copy-paste.

## Usage

1. Add to your Gemfile `gem 'the_schema_is'` and run `bundle install`.
2. Add to your `.rubocop.yml` this:
  ```yaml
  require:
    - the_schema_is/cops
  ```
3. Run `rubocop` and see what it now says about your models.
4. Now you can add schema definitions manually, or allow `rubocop --auto-correct` (or `-a`) to do its job! NB: you can always use `rubocop --auto-correct --only TheSchemaIs` to auto-correct ONLY this schema thing

To make reporting cleaner, all cops are split into:

* `Presence`
* `MissingColumn`
* `UnknownColumn`
* `WrongColumnDefinition`

It is not advisable to selectively turn them off, but you may know better (for example, some may experiment with leaving in models just `t.<type> '<name>'` without details about defaults and limit, and therefore turn off `WrongColumnDefinition`), all of it is pretty experimental!

## Setting

`the_schema_is` cops support some configuration, which should be done on the namespace level in your `.rubocop.yml`, for example:

```yaml
TheSchemaIs:
  Schema: db/other-schema-file.rb
```

Currently available settings are:

* `TablePrefix` to help `the_schema_is` deduce table name from class name;
* `Schema` to set path to schema (by default `db/schema.rb`)
* `BaseClass` to help `the_schema_is` guess what is a model class (by default `ApplicationRecord` and `ActiveRecord::Base`).

So, if you have your custom-named base class, you should do:

```yaml
TheSchemaIs:
  BaseClass: OurOwnBase
```

Note that Rubocop allows per-folder settings out of the box, which allows TheSchemaIs, even at the tender version of 0.0.3, to support complicated configurations with multiple databases and engines.

For example, consider your models are split into `app/models/users/` and `app/models/products` which are stored in the different databases, then you probably have different schemas and base classes for them. So, to configure it properly, you might want to do in `app/models/users/.rubocop.yml`:

```yaml
# Don't forget this for all other cop settings to not be ignored
inherit_from: ../../../.rubocop.yml

TheSchemaIs:
  BaseClass: Users::BaseRecord
  Schema: db/users_schema.rb
```

## Some Q&A

* **Q: It doesn't check the actual DB?**
  * A: No, it does not! At the current moment, our belief is that in a healthy Rails codebase `schema.rb` is always corresponding to DB state, so checking against it is enough. This approach makes the tooling much easier (with existing Rubocop's ecosystem of parsers/offenses/configurations).
* **Q: What if I don't use Rubocop?**
  * A: You may want to try, at least? Do you know that you may disable or configure most of its checks to your liking? And auto-correct any code to your preferences?.. Or automatically create "TODO" config-file (which disables all the cops currently raising offenses, and allows to review them and later setup one-by-one)?.. It is much more than "linter making your code to complain about some rigid style guide".
* **Q: Cool, but I still don't want to.**
  * A: ...OK, then you can disable all cops _except_ for `TheSchemaIs` namespace :)
* **How do I annotate my fabrics, model specs, routes, controllers, ... (which `annotate` allows)?**
  * A: You don't. The same way you don't copy-paste the whole definition of the class into spec file which tests this class: Definition is in one place, tests and other code using this definition is another. DRY!
* **Rubocop is unhappy with the code `TheSchemaIs` generated**.
  * A: There are two known things in generated `the_schema_is` blocks that Rubocop may complain about:
    * Usage of double quotes for strings, if your config insists on single quotes: that's because we just copy code objects from `schema.rb`. Rubocop's auto-correct will fix it :) (Even in one run: "fixing TheSchemaIs, then fixing quotes");
    * Too long blocks (if you have tables with dozens of columns, God forbid... as we do). It can be fixed by adding this to `.rubocop.yml`:
  ```yaml
  Metrics/BlockLength:
    ExcludedMethods:
      - the_schema_is
  ```

## Author and License

[Victor Shepelev aka "zverok"](https://zverok.github.io), MIT.
