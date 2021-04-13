# Ancestry Changelog

Doing our best at supporting [SemVer](http://semver.org/) with
a nice looking [Changelog](http://keepachangelog.com).

## Version [HEAD] <sub><sup>now</sub></sup>

## Version [4.0.0] <sub><sup>2021-04-12</sub></sup>

* dropped support for rails 4.2 and 5.0 (thx @d-m-u)
* better documentation counter cache option (thx @pustomytnyk)
* clean up code (thx @amatsuda @d-m-u)
* fixed rails 6.1 support (thx @cmr119 @d-staehler @danini-the-panini )
* phasing out `parent_id?`, `ancestors?` and using `has_parent?` instead
* fixed postgres order bug on rails 6.2 and higher (thx @smoyt)

## Version [3.2.1] <sub><sup>2020-09-23</sub></sup>

* fixed gemspec to include locales and pg (thx @HectorMF)

## Version [3.2.0] <sub><sup>2020-09-23</sub></sup>

* introduce i18n
* pg sql optimization for ancestry changes (thx @suonlight and @geis)
* pg sql optimization for sorting (thx @brendon and @d-m-u)
* fix to humanise model name (thx @mkllnk)
* able to convert to ancestry from a parent_id column with a different name
* documentation fixes for better diagrams and grammar (thx @dtamais, @d-m-u, and @CamilleDrapier)

## Version [3.1.0] <sub><sup>2020-08-03</sub></sup>

* `:primary_key_format` method lets you change syntax. good for uuids.
* changed code from being `ancestry` string to `ancestry_ids` focused. May break monkey patches.
* Moved many methods from `has_ancestry` and `InstanceMethods` to `MaterializedPath`. May break monkey patches.
* Removed tests for `mysql` driver. Starting with rails 4.1, it supports `mysql2` driver.
* Better documentation for relationships (thnx @dtamai and @d-m-u)
* Fix creating children in `after_*` callbacks (thx @jstirk)

## Version [3.0.7] <sub><sup>2018-11-06</sub></sup>

* Fixed rails 5.1 change detection (thx @jrafanie)
* Introduce counter cache (thx @hw676018683)

## Version [3.0.6] <sub><sup>2018-11-06</sub></sup>

* Fixed rails 4.1 version check (thx @myxoh)

## Version [3.0.5] <sub><sup>2018-11-06</sub></sup>

## Changed

* Added indirect children support (thx @tilo)
* Fixed test sorting for pg on mac osx

## Fixes

* Reduced memory footprint of parsing ancestry column (thx @NickLaMuro)

## Version [3.0.4] <sub><sup>2018-10-27</sub></sup>

## Fixes

* Properly detects non-integer columns (thx @adam101)
* Arrange no longer drops nodes due to missing parents (thx @trafium)

## Version [3.0.3] <sub><sup>2018-10-23</sub></sup>

This branch (3.x) should still be compatible with rails 3 and 4.
Rails 5.1 and 5.2 support were introduced in this version, but ongoing support
has been moved to ancestry 4.0

## Fixes

* Reduce object allocation (thx @NickLaMuro)
* Rails 5.1 fixes (thx @ctrombley)
* Avoid redundant query to DB in subtree_of scope (thx @Slike9)
* Syntax tweaks (thx @ekohl, @richardonrails)
* Fixed reverse ordering
* Dropped builds for ruby 1.9.3, 2.0, 2.1, and 2.2
* Dropped builds for Rails 3.x and 4.x (will use Active Record `or` syntax)

## Version [3.0.2] <sub><sup>2018-04-24</sub></sup>

## Fixes

* fixed `order_by_ancestry` bug
* fixed order tests for postgres on mac (it uses a different collation)
* fixed documentation (thx @besquared, @danfrenette, @eiwi1101, @isimluk, @mabusaad, @tilsammans)
* added missing `Ancestry::version`
* added Rails 5.2 support (thx @jjuliano)

## Version [3.0.1] <sub><sup>2017-07-05</sub></sup>

## Fixes

* added gem metadata
* fixed keep a changelog link (thx @mattbrictson)
* added alias has_parent?
* fixed bug where unscoping too much (thx @brendon)
* fixed tests on mysql 5.7 and rails 3.2
* Dropped 3.1 scope changes

## Version [3.0.0] <sub><sup>2017-05-18</sub></sup>

## Changed

* Dropping Rails 3.0, and 3.1. Added Rails 5.1 support (thx @ledermann)
* Dropping Rails 4.0, 4.1 for build reasons. Since 4.2 is supported, all 4.x should still work.

## Fixes

* Performance: Use `pluck` vs `map` for ids (thx @njakobsen and @culturecode)
* Fixed acts_as_tree compatibility (thx @crazymykl)
* Fixed loading ActiveRails prematurely (thx @vovimayhem)
* Fixes exist (thx @ledermann)
* Properly touches parents when different class for STI (thx @samtgarson)
* Fixed issues with parent_id (only present on master) (thx @domcleal)

## Version [2.2.2] <sub><sup>2016-11-01</sub></sup>

### Changed

* Use `COALESCE` only for sorting versions greater than 5.0
* Fixed bug with explicit order clauses (introduced in 2.2.0)
* No longer load schema on `has_ancestry` load (thx @ledermann)

## Version [2.2.1] <sub><sup>2016-10-25</sub></sup>

Sorry for blip, local master got out of sync with upstream master.
Missed 2 commits (which are feature adds)

### Added
* Use like (vs ilike) for rails 5.0 (performance enhancement)
* Use `COALESCE` for sorting on pg, mysql, and sqlite vs `CASE`

## Version [2.2.0] <sub><sup>2016-10-25</sub></sup>

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

## Version [2.1.0] <sub><sup>2014-04-16</sub></sup>
* Added arrange_serializable (thx @krishandley, @chicagogrrl)
* Add the :touch to update ancestors on save (thx @adammck)
* Change conditions into arel (thx @mlitwiniuk)
* Added children? & siblings? alias (thx @bigtunacan)
* closure_tree compatibility (thx @gzigzigzeo)
* Performance tweak (thx @mjc)
* Improvements to organization (thx @xsuchy, @ryakh)

## Version [2.0.0] <sub><sup>2013-05-17</sub></sup>
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

## Version [1.3.0] <sub><sup>2012-05-04</sub></sup>
* Ancestry now ignores default scopes when moving or destroying nodes, ensuring tree consistency
* Changed ActiveRecord dependency to 2.3.14

## Version [1.2.5] <sub><sup>2012-03-15</sub></sup>
* Fixed warnings: "parenthesize argument(s) for future version"
* Fixed a bug in the restore_ancestry_integrity! method (thx Arthur Holstvoogd)

## Version [1.2.4] <sub><sup>2011-04-22</sub></sup>
* Prepended table names to column names in queries (thx @raelik)
* Better check to see if acts_as_tree can be overloaded (thx @jims)
* Performance inprovements (thx @kueda)

## Version [1.2.3] <sub><sup>2010-10-28</sub></sup>
* Fixed error with determining ActiveRecord version
* Added option to specify :primary_key_format (thx @rolftimmermans)

## Version [1.2.2] <sub><sup>2010-10-24</sub></sup>
* Fixed all deprecation warnings for rails 3.0.X
* Added `:report` option to `check_ancestry_integrity!`
* Changed ActiveRecord dependency to 2.2.2
* Tested and fixed for ruby 1.8.7 and 1.9.2
* Changed usage of `update_attributes` to `update_attribute` to allow ancestry column protection

## Version [1.2.0] <sub><sup>2009-11-07</sub></sup>
* Removed some duplication in has_ancestry
* Cleaned up plugin pattern according to http://yehudakatz.com/2009/11/12/better-ruby-idioms/
* Moved parts of ancestry into seperate files
* Made it possible to pass options into the arrange method
* Renamed acts_as_tree to has_ancestry
* Aliased has_ancestry as acts_as_tree if acts_as_tree is available
* Added subtree_of scope
* Updated ordered_by_ancestry scope to support Microsoft SQL Server
* Added empty hash as parameter to exists? calls for older ActiveRecord versions

## Version [1.1.4] <sub><sup>2009-11-07</sub></sup>
* Thanks to a patch from tom taylor, Ancestry now works with different primary keys

## Version [1.1.3] <sub><sup>2009-11-01</sub></sup>
* Fixed a pretty bad bug where several operations took far too many queries

## Version [1.1.2] <sub><sup>2009-10-29</sub></sup>
* Added validation for depth cache column
* Added STI support (reported broken)

## Version [1.1.1] <sub><sup>2009-10-28</sub></sup>
* Fixed some parentheses warnings that where reported
* Fixed a reported issue with arrangement
* Fixed issues with ancestors and path order on postgres
* Added ordered_by_ancestry scope (needed to fix issues)

## Version [1.1.0] <sub><sup>2009-10-22</sub></sup>
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

## Version 1.0.0 <sub><sup>2009-10-16</sub></sup>
* Initial version
* Tree building
* Tree navigation
* Integrity checking / restoration
* Arrangement
* Orphan strategies
* Subtree movement
* Named scopes
* Validations


[HEAD]: https://github.com/stefankroes/ancestry/compare/v4.0.0...HEAD
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
