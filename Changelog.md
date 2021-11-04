# the-schema-is changes

## 2021-11-04 - 0.0.5

* Support `enum` column type;
* Add `RemoveDefinitions` config key for leaner `the_schema_is` definitions (avoiding huge index descriptions in models).

## 2021-09-15 - 0.0.4

* Get rid of [Fast](https://jonatas.github.io/fast/) dependency. It is cool, but we switched to use Rubocop's own `NodePattern` to lessen the dependency burden (Fast was depending on [astrolabe](https://github.com/yujinakayama/astrolabe) which wasn't updated in 6 years, locking parser dependency to old version and making Fast incompatible with newer Rubocop);
* Introduce mandatory table name in the `the_schema_is` DSL (and the `WrongTableName` cop to check it);
* Internally, change cop classes to comply to newer (> 1.0) Rubocop API.

## 2020-05-07 - 0.0.3

First really working release.
