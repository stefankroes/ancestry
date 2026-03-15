# Ancestry Changelog

Doing our best at supporting [SemVer](http://semver.org/) with
a nice looking [Changelog](http://keepachangelog.com).

## Version [Unreleased]

* Introduce virtual columns for `parent_id`, `root_id`, and `depth`. (mysql doesn't support `root: :virtual`) [#727](https://github.com/stefankroes/ancestry/pull/727) [#721](https://github.com/stefankroes/ancestry/pull/721) (addresses [#679](https://github.com/stefankroes/ancestry/issues/679), [#354](https://github.com/stefankroes/ancestry/issues/354), [#422](https://github.com/stefankroes/ancestry/issues/422))
* Introduce `leaves` scope, `node.leaves`, `leaf_ids`, and `leaf?` [#725](https://github.com/stefankroes/ancestry/pull/725) [#726](https://github.com/stefankroes/ancestry/pull/726) (thx @asmega, @brendon for prior leaf node approaches in [#246](https://github.com/stefankroes/ancestry/pull/246), [#341](https://github.com/stefankroes/ancestry/pull/341))
* Introduce `belongs_to :parent`, `belongs_to :root`, and `has_many :children` associations [#723](https://github.com/stefankroes/ancestry/pull/723) (addresses [#308](https://github.com/stefankroes/ancestry/issues/308), [#63](https://github.com/stefankroes/ancestry/issues/63), [#195](https://github.com/stefankroes/ancestry/pull/195))
* Introduce `parent` and `root` caching in a physical column [#721](https://github.com/stefankroes/ancestry/pull/721)
* Fixed deprecation warning [#724](https://github.com/stefankroes/ancestry/pull/724)
* Fix: `root_id` for PostgreSQL [#722](https://github.com/stefankroes/ancestry/pull/722)

### Breaking Changes

* Fix: cascading moves (moving a node whose ancestry was changed by a prior move in the
  same request) no longer orphan descendants. A `before_update` callback now refreshes
  stale in-memory ancestry from the database before `update_descendants` runs. The
  `update_descendants` callback remains `after_update` — existing callback ordering is
  preserved.
* `ancestry_column` and `ancestry_delimiter` were deprecated, but have been officially removed.
* `depth_cache_column`, `counter_cache_column`, and `touch_ancestors` class variables have been removed.
* `MaterializedPathPg` (internal module) has been removed.
* Instance and Class methods are now generated.

## Version [5.1.0] <sub><sup>2026-03-10</sup></sub>

* `update_strategy: :sql` now works on all databases (SQLite, MySQL, PostgreSQL) [#715](https://github.com/stefankroes/ancestry/pull/715)
* Introduce depth constraint validation for subtree moves [#713](https://github.com/stefankroes/ancestry/pull/713) (thx @wilburhimself)
* Fix: CHANGELOG HTML entity fix [#712](https://github.com/stefankroes/ancestry/pull/712) (thx @biow0lf)
* Testing Ruby 4.0 support [#709](https://github.com/stefankroes/ancestry/pull/709) (thx @fkmy)
* Tested against Ruby 2.7–4.0 and Rails 6.0–8.1 [#716](https://github.com/stefankroes/ancestry/pull/716)

### Deprecations

These class-level accessors still work but are being phased out.
We are moving configuration into baked method bodies and away from class variables.
If you depend on reading these at runtime, now is a good time to find alternatives:

* `ancestry_column`, `ancestry_delimiter`, `depth_cache_column`, `counter_cache_column`, `touch_ancestors`

### Breaking Changes

* `sort_by_ancestry` and `check_ancestry_integrity!` now delegate to `_sort_by_ancestry` and
  `_check_ancestry_integrity!` with an explicit column parameter. The public API is unchanged.

## Version [5.0.0] <sub><sup>2026-02-08</sup></sub>

* Fix: `siblings` now excludes self [#710](https://github.com/stefankroes/ancestry/pull/710) (thx @chikamichi)
* Introduce `orphan_strategy: :none` [#658](https://github.com/stefankroes/ancestry/pull/658)
* Introduce `rebuild_counter_cache!` to reset counter caches. [#663](https://github.com/stefankroes/ancestry/pull/663) [#668](https://github.com/stefankroes/ancestry/pull/668) (thx @RongRongTeng)
* Introduce `in_subtree_of?` instance method [#680](https://github.com/stefankroes/ancestry/pull/680) (thx @instrumentl)
* Optimize `has_siblings?` to use `exists?` [#693](https://github.com/stefankroes/ancestry/pull/693) (thx @a5-stable)
* Fix: humanise model name in error messages [#700](https://github.com/stefankroes/ancestry/pull/700) (thx @labeebklatif)
* Fix: touch with sql update strategy
* Introduce `update_strategy: :sql` hooks for extension developers
* Added support for virtual depth column
* Documentation fixes [#664](https://github.com/stefankroes/ancestry/pull/664) [#667](https://github.com/stefankroes/ancestry/pull/667) (thx @motokikando, @onerinas)
* Introduce `build_cache_depth_sql!`, a sql alternative to `build_cache_depth` [#654](https://github.com/stefankroes/ancestry/pull/654)
* Drop `ancestry_primary_key_format` [#649](https://github.com/stefankroes/ancestry/pull/649)
* When destroying orphans, going from leafs up to node [#635](https://github.com/stefankroes/ancestry/pull/635) (thx @brendon)
* Changed config setters to class readers [#633](https://github.com/stefankroes/ancestry/pull/633) (thx @kshurov)
* Split apply_orphan_strategy into multiple methods [#632](https://github.com/stefankroes/ancestry/pull/633) [#633](https://github.com/stefankroes/ancestry/pull/617)
* Ruby 3.4 support
* Rails 8.0 support

### Notable features

Depth scopes now work without `cache_depth`. But please only use this in background
jobs. If you need to do this in the ui, please use `cache_depth`.

`build_cache_depth_sql!` is quicker than `build_cache_depth!` (1 query instead of N+1 queries).

### Deprecations

* Option `:depth_cache_column` is going away.
  Please use a single key instead: `cache_depth: :depth_cach_column_name`.
  `cache_depth: true` still defaults to `ancestry_depth`.

### Breaking Changes

* `siblings` no longer returns self. This is a bug fix, but does change behavior.
* Dropped support for Rails < 6.1
* Renamed internal methods to follow Rails conventions: `*_before_save` methods renamed to `*_before_last_save`
  (e.g., `child_ancestry_before_save` => `child_ancestry_before_last_save`)
* Options are no longer set via class methods. Using `has_ancestry` is now the only way to enable these features.
  These are all not part of the public API.
  * These are now class level read only accessors
    * `ancestry_base_class`         (introduced 1.1, removed by #633)
    * `ancestry_column`             (introduced 1.2, removed by #633)
    * `ancestry_delimiter`          (introduced 4.3.0, removed by #633)
    * `depth_cache_column`          (introduced 4.3.0, removed by #654)
  * These no longer have any accessors
    * `ancestry_format`             (introduced 4.3.0, removed by #654)
    * `orphan_strategy`             (introduced 1.1, removed by #617)
    * `ancestry_primary_key_format` (introduced 4.3.0, removed by #649)
    * `touch_ancestors`             (introduced 2.1, removed by TODO)
* These are seen as internal and may go away:
  * `apply_orphan_strategy` Please use `orphan_strategy: :none` and a custom `before_destory` instead.

## Version [4.3.3] <sub><sup>2023-04-01</sup></sub>

* Fix: sort_by_ancesty with custom ancestry_column [#656](https://github.com/stefankroes/ancestry/pull/656) (thx @mitsuru)

## Version [4.3.2] <sub><sup>2023-03-25</sup></sub>

* Fix: added back fields that were removed in #589 [#647](https://github.com/stefankroes/ancestry/pull/647) (thx @rastamhadi)
  * path_ids_in_database

## Version [4.3.1] <sub><sup>2023-03-19</sup></sub>

* Fix: added back fields that were removed in #589 [#637](https://github.com/stefankroes/ancestry/pull/637) (thx @znz)
  * ancestor_ids_in_database
  * parent_id_in_database

## Version [4.3.0] <sub><sup>2023-03-09</sup></sub>

* Fix: materialized_path2 strategy [#597](https://github.com/stefankroes/ancestry/pull/597) (thx @kshnurov)
* Fix: descendants ancestry is now updated in after_update callbacks [#589](https://github.com/stefankroes/ancestry/pull/589) (thx @kshnurov)
* Document updated grammar [#594](https://github.com/stefankroes/ancestry/pull/594) (thx @omarr-gamal)
* Documented `update_strategy` [#588](https://github.com/stefankroes/ancestry/pull/588) (thx @victorfgs)
* Fix: fixed has_parent? when non-default primary id [#585](https://github.com/stefankroes/ancestry/pull/585) (thx @Zhong-z)
* Documented column collation and testing [#601](https://github.com/stefankroes/ancestry/pull/601) [#607](https://github.com/stefankroes/ancestry/pull/607) (thx @kshnurov)
* Added initializer with default_ancestry_format [#612](https://github.com/stefankroes/ancestry/pull/612) [#613](https://github.com/stefankroes/ancestry/pull/613)
* ruby 3.2 support [#596](https://github.com/stefankroes/ancestry/pull/596) (thx @petergoldstein)
* Reduce memory for sort_by_ancestry [#415](https://github.com/stefankroes/ancestry/pull/415)

### Notable features

Default configuration values are provided for a few options: `update_strategy`, `ancestry_format`, and `primary_key_format`.
These can be set in an initializer via `Ancestry.default_{ancestry_format} = value`

A new `ancestry_format` of `:materialized_path2` formats the ancestry column with leading and trailing slashes.
It shows promise to make the `ancestry` field more sql friendly.

Both of these are better documented in [the readme](/README.md).

### Breaking changes

* `ancestry_primary_key_format` is now specified or a single key not the whole regular expression.
  We used to accept `/\A[0-9]+(/[0-9]+)*` or `'[0-9]'`, but now we only accept `'[0-9]'`.

## Version [4.2.0] <sub><sup>2022-06-09</sup></sub>

* added strategy: materialized_path2 [#571](https://github.com/stefankroes/ancestry/pull/571)
* Added tree_view method [#561](https://github.com/stefankroes/ancestry/pull/561) (thx @bizcho)
* Fixed bug when errors would not undo callbacks [#566](https://github.com/stefankroes/ancestry/pull/566) (thx @daniloisr)
* ruby 3.0 support
* rails 7.0 support (thx @chenillen, @petergoldstein)
* Documentation fixes (thx @benkoshy, @mijoharas)

## Version [4.1.0] <sub><sup>2021-06-25</sup></sub>

* `parent` with an invalid id now returns nil (thx @vanboom)
* `root` returns self if ancestry is invalid (thx @vanboom)
* fix case where invalid object prevented ancestry updates (thx @d-m-u)
* oracleenhanced uses nulls first for sorting (thx @lual)
* fix counter cache and STI (thx @mattvague)

## Version [4.0.0] <sub><sup>2021-04-12</sup></sub>

* dropped support for rails 4.2 and 5.0 (thx @d-m-u)
* better documentation counter cache option (thx @pustomytnyk)
* clean up code (thx @amatsuda @d-m-u)
* fixed rails 6.1 support (thx @cmr119 @d-staehler @danini-the-panini)
* phasing out `parent_id?`, `ancestors?` and using `has_parent?` instead
* fixed postgres order bug on rails 6.2 and higher (thx @smoyt)

## Version [3.2.1] <sub><sup>2020-09-23</sup></sub>

* fixed gemspec to include locales and pg (thx @HectorMF)

## Version [3.2.0] <sub><sup>2020-09-23</sup></sub>

* introduce i18n
* pg sql optimization for ancestry changes (thx @suonlight and @geis)
* pg sql optimization for sorting (thx @brendon and @d-m-u)
* fix to humanize model name (thx @mkllnk)
* able to convert to ancestry from a parent_id column with a different name
* documentation fixes for better diagrams and grammar (thx @dtamais, @d-m-u, and @CamilleDrapier)

## Version [3.1.0] <sub><sup>2020-08-03</sup></sub>

* `:primary_key_format` method lets you change syntax. good for uuids.
* changed code from being `ancestry` string to `ancestry_ids` focused. May break monkey patches.
* Moved many methods from `has_ancestry` and `InstanceMethods` to `MaterializedPath`. May break monkey patches.
* Removed tests for `mysql` driver. Starting with rails 4.1, it supports `mysql2` driver.
* Better documentation for relationships (thnx @dtamai and @d-m-u)
* Fix creating children in `after_*` callbacks (thx @jstirk)

## Version [3.0.7] <sub><sup>2018-11-06</sup></sub>

* Fixed rails 5.1 change detection (thx @jrafanie)
* Introduce counter cache (thx @hw676018683)

## Version [3.0.6] <sub><sup>2018-11-06</sup></sub>

* Fixed rails 4.1 version check (thx @myxoh)

## Version [3.0.5] <sub><sup>2018-11-06</sup></sub>

### Changed

* Added indirect children support (thx @tilo)
* Fixed test sorting for pg on mac osx

### Fixes

* Reduced memory footprint of parsing ancestry column (thx @NickLaMuro)

## Version [3.0.4] <sub><sup>2018-10-27</sup></sub>

### Fixes

* Properly detects non-integer columns (thx @adam101)
* Arrange no longer drops nodes due to missing parents (thx @trafium)

## Version [3.0.3] <sub><sup>2018-10-23</sup></sub>

This branch (3.x) should still be compatible with rails 3 and 4.
Rails 5.1 and 5.2 support were introduced in this version, but ongoing support
has been moved to ancestry 4.0

### Fixes

* Reduce object allocation (thx @NickLaMuro)
* Rails 5.1 fixes (thx @ctrombley)
* Avoid redundant query to DB in subtree_of scope (thx @Slike9)
* Syntax tweaks (thx @ekohl, @richardonrails)
* Fixed reverse ordering
* Dropped builds for ruby 1.9.3, 2.0, 2.1, and 2.2
* Dropped builds for Rails 3.x and 4.x (will use Active Record `or` syntax)

## Version [3.0.2] <sub><sup>2018-04-24</sup></sub>

### Fixes

* fixed `order_by_ancestry` bug
* fixed order tests for postgres on mac (it uses a different collation)
* fixed documentation (thx @besquared, @danfrenette, @eiwi1101, @isimluk, @mabusaad, @tilsammans)
* added missing `Ancestry::version`
* added Rails 5.2 support (thx @jjuliano)

## Version [3.0.1] <sub><sup>2017-07-05</sup></sub>

### Fixes

* added gem metadata
* fixed keep a changelog link (thx @mattbrictson)
* added alias has_parent?
* fixed bug where unscoping too much (thx @brendon)
* fixed tests on mysql 5.7 and rails 3.2
* Dropped 3.1 scope changes

## Version [3.0.0] <sub><sup>2017-05-18</sup></sub>

### Changed

* Dropping Rails 3.0, and 3.1. Added Rails 5.1 support (thx @ledermann)
* Dropping Rails 4.0, 4.1 for build reasons. Since 4.2 is supported, all 4.x should still work.

### Fixes

* Performance: Use `pluck` vs `map` for ids (thx @njakobsen and @culturecode)
* Fixed acts_as_tree compatibility (thx @crazymykl)
* Fixed loading ActiveRails prematurely (thx @vovimayhem)
* Fixes exist (thx @ledermann)
* Properly touches parents when different class for STI (thx @samtgarson)
* Fixed issues with parent_id (only present on master) (thx @domcleal)

## Version [2.2.2] <sub><sup>2016-11-01</sup></sub>

### Changed

* Use `COALESCE` only for sorting versions greater than 5.0
* Fixed bug with explicit order clauses (introduced in 2.2.0)
* No longer load schema on `has_ancestry` load (thx @ledermann)

## Version [2.2.1] <sub><sup>2016-10-25</sup></sub>

Sorry for blip, local master got out of sync with upstream master.
Missed 2 commits (which are feature adds)

### Added

* Use like (vs ilike) for rails 5.0 (performance enhancement)
* Use `COALESCE` for sorting on pg, mysql, and sqlite vs `CASE`

## Version [2.2.0] <sub><sup>2016-10-25</sup></sub>

### Added

* Predicates for scopes: e.g.: `ancestor_of?`, `parent_of?` (thx @neglectedvalue)
* Scope `path_of`

### Changed

* `arrange` now accepts blocks (thx @mastfish)
* Performance tuning `arrange_node` (thx @fryguy)
* In orphan strategy, set `ancestry` to `nil` for no parents (thx @haslinger)
* Only updates `updated_at` when a record is changed (thx @brocktimus)
* No longer casts text primary key as an integer
* Upgrading tests for ruby versions (thx @brocktimus, @fryguy, @yui-knk)
* Fix non-default ancestry not getting used properly (thx @javiyu)

## Version [2.1.0] <sub><sup>2014-04-16</sup></sub>

* Added arrange_serializable (thx @krishandley, @chicagogrrl)
* Add the :touch to update ancestors on save (thx @adammck)
* Change conditions into arel (thx @mlitwiniuk)
* Added children? & siblings? alias (thx @bigtunacan)
* closure_tree compatibility (thx @gzigzigzeo)
* Performance tweak (thx @mjc)
* Improvements to organization (thx @xsuchy, @ryakh)

## Version [2.0.0] <sub><sup>2013-05-17</sup></sub>

* Removed rails 2 compatibility
* Added table name to condition constructing methods (thx @aflatter)
* Fix depth_cache not being updated when moving up to ancestors (thx @scottatron)
* add alias :root? to existing is_root? (thx @divineforest)
* Add block to sort_by_ancestry (thx @Iliya)
* Add attribute query method for parent_id (thx @sj26)
* Fixed and tested for rails 4 (thx @adammck, @Nihad, @Systho, @Philippe, e.a.)
* Fixed overwriting ActiveRecord::Base.base_class (thx @Rozhnov)
* New adopt strategy (thx unknown)
* Many more improvements

## Version [1.3.0] <sub><sup>2012-05-04</sup></sub>

* Ancestry now ignores default scopes when moving or destroying nodes, ensuring tree consistency
* Changed ActiveRecord dependency to 2.3.14

## Version [1.2.5] <sub><sup>2012-03-15</sup></sub>

* Fixed warnings: "parenthesize argument(s) for future version"
* Fixed a bug in the restore_ancestry_integrity! method (thx Arthur Holstvoogd)

## Version [1.2.4] <sub><sup>2011-04-22</sup></sub>

* Prepended table names to column names in queries (thx @raelik)
* Better check to see if acts_as_tree can be overloaded (thx @jims)
* Performance improvements (thx @kueda)

## Version [1.2.3] <sub><sup>2010-10-28</sup></sub>

* Fixed error with determining ActiveRecord version
* Added option to specify :primary_key_format (thx @rolftimmermans)

## Version [1.2.2] <sub><sup>2010-10-24</sup></sub>

* Fixed all deprecation warnings for rails 3.0.X
* Added `:report` option to `check_ancestry_integrity!`
* Changed ActiveRecord dependency to 2.2.2
* Tested and fixed for ruby 1.8.7 and 1.9.2
* Changed usage of `update_attributes` to `update_attribute` to allow ancestry column protection

## Version [1.2.0] <sub><sup>2009-11-07</sup></sub>

* Removed some duplication in has_ancestry
* Cleaned up plugin pattern according to http://yehudakatz.com/2009/11/12/better-ruby-idioms/
* Moved parts of ancestry into separate files
* Made it possible to pass options into the arrange method
* Renamed acts_as_tree to has_ancestry
* Aliased has_ancestry as acts_as_tree if acts_as_tree is available
* Added subtree_of scope
* Updated ordered_by_ancestry scope to support Microsoft SQL Server
* Added empty hash as parameter to exists? calls for older ActiveRecord versions

## Version [1.1.4] <sub><sup>2009-11-07</sup></sub>

* Thanks to a patch from tom taylor, Ancestry now works with different primary keys

## Version [1.1.3] <sub><sup>2009-11-01</sup></sub>

* Fixed a pretty bad bug where several operations took far too many queries

## Version [1.1.2] <sub><sup>2009-10-29</sup></sub>

* Added validation for depth cache column
* Added STI support (reported broken)

## Version [1.1.1] <sub><sup>2009-10-28</sup></sub>

* Fixed some parentheses warnings that where reported
* Fixed a reported issue with arrangement
* Fixed issues with ancestors and path order on postgres
* Added ordered_by_ancestry scope (needed to fix issues)

## Version [1.1.0] <sub><sup>2009-10-22</sup></sub>

* Depth caching (and cache rebuilding)
* Depth method for nodes
* Named scopes for selecting by depth
* Relative depth options for tree navigation methods:
  * ancestors
  * path
  * descendants
  * descendant_ids
  * subtree
  * subtree_ids
* Updated README
* Easy migration from existing plugins/gems
* acts_as_tree checks unknown options
* acts_as_tree checks that options are hash
* Added a bang (!) to the integrity functions
  * Since these functions should only be used from ./script/console and not
    from your application, this change is not considered as breaking backwards
    compatibility and the major version wasn't bumped.
* Updated install script to point to documentation
* Removed rails specific init
* Removed uninstall script

## Version 1.0.0 <sub><sup>2009-10-16</sup></sub>

* Initial version
* Tree building
* Tree navigation
* Integrity checking / restoration
* Arrangement
* Orphan strategies
* Subtree movement
* Named scopes
* Validations

[Unreleased]: https://github.com/stefankroes/ancestry/compare/v5.1.0...HEAD
[5.1.0]: https://github.com/stefankroes/ancestry/compare/v5.0.0...v5.1.0
[5.0.0]: https://github.com/stefankroes/ancestry/compare/v4.3.3...v5.0.0
[4.3.3]: https://github.com/stefankroes/ancestry/compare/v4.3.2...v4.3.3
[4.3.2]: https://github.com/stefankroes/ancestry/compare/v4.3.1...v4.3.2
[4.3.1]: https://github.com/stefankroes/ancestry/compare/v4.3.0...v4.3.1
[4.3.0]: https://github.com/stefankroes/ancestry/compare/v4.2.0...v4.3.0
[4.2.0]: https://github.com/stefankroes/ancestry/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/stefankroes/ancestry/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/stefankroes/ancestry/compare/v3.2.1...v4.0.0
[3.2.1]: https://github.com/stefankroes/ancestry/compare/v3.2.0...v3.2.1
[3.2.0]: https://github.com/stefankroes/ancestry/compare/v3.1.0...v3.2.0
[3.1.0]: https://github.com/stefankroes/ancestry/compare/v3.0.7...v3.1.0
[3.0.7]: https://github.com/stefankroes/ancestry/compare/v3.0.6...v3.0.7
[3.0.6]: https://github.com/stefankroes/ancestry/compare/v3.0.5...v3.0.6
[3.0.5]: https://github.com/stefankroes/ancestry/compare/v3.0.4...v3.0.5
[3.0.4]: https://github.com/stefankroes/ancestry/compare/v3.0.3...v3.0.4
[3.0.3]: https://github.com/stefankroes/ancestry/compare/v3.0.2...v3.0.3
[3.0.2]: https://github.com/stefankroes/ancestry/compare/v3.0.1...v3.0.2
[3.0.1]: https://github.com/stefankroes/ancestry/compare/v3.0.0...v3.0.1
[3.0.0]: https://github.com/stefankroes/ancestry/compare/v2.2.2...v3.0.0
[2.2.2]: https://github.com/stefankroes/ancestry/compare/v2.2.1...v2.2.2
[2.2.1]: https://github.com/stefankroes/ancestry/compare/v2.2.0...v2.2.1
[2.2.0]: https://github.com/stefankroes/ancestry/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/stefankroes/ancestry/compare/v2.0.0...v2.1.0
[2.0.0]: https://github.com/stefankroes/ancestry/compare/v1.3.0...v2.0.0
[1.3.0]: https://github.com/stefankroes/ancestry/compare/v1.2.5...v1.3.0
[1.2.5]: https://github.com/stefankroes/ancestry/compare/v1.2.4...v1.2.5
[1.2.4]: https://github.com/stefankroes/ancestry/compare/v1.2.3...v1.2.4
[1.2.3]: https://github.com/stefankroes/ancestry/compare/v1.2.2...v1.2.3
[1.2.2]: https://github.com/stefankroes/ancestry/compare/v1.2.0...v1.2.2
[1.2.0]: https://github.com/stefankroes/ancestry/compare/v1.1.4...v1.2.0
[1.1.4]: https://github.com/stefankroes/ancestry/compare/v1.1.3...v1.1.4
[1.1.3]: https://github.com/stefankroes/ancestry/compare/v1.1.2...v1.1.3
[1.1.2]: https://github.com/stefankroes/ancestry/compare/v1.1.1...v1.1.2
[1.1.1]: https://github.com/stefankroes/ancestry/compare/v1.1.0...v1.1.1
[1.1.0]: https://github.com/stefankroes/ancestry/compare/v1.0.0...v1.1.0
