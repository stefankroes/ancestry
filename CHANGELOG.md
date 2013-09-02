# Ancestry Changelog

The latest version of ancestry is recommended. The three numbers of each version
numbers are respectively the major, minor and patch versions. We started with
major version 1 because it looks so much better and ancestry was already quite
mature and complete when it was published. The major version is only bumped when
backwards compatibility is broken. The minor version is bumped when new features
are added. The patch version is bumped when bugs are fixed.

## Version 2.0.0 (2013-05-17)
* Removed rails 2 compatibility
* Added table name to condition constructing methods (thx aflatter)
* Fix depth_cache not being updated when moving up to ancestors (thx scottatron)
* add alias :root? to existing is_root? (thx divineforest)
* Add block to sort_by_ancestry (thx Iliya)
* Add attribute query method for parent_id (thx sj26)
* Fixed and tested for rails 4 (thx adammck, Nihad, Systho, Philippe, e.a.)
* Fixed overwriting ActiveRecord::Base.base_class (thx Rozhnov)
* New adopt strategy (thx unknown)
* Many more improvements

## Version 1.3.0 (2012-05-04)
* Ancestry now ignores default scopes when moving or destroying nodes, ensuring tree consistency
* Changed ActiveRecord dependency to 2.3.14

## Version 1.2.5 (2012-03-15)
* Fixed warnings: "parenthesize argument(s) for future version"
* Fixed a bug in the restore_ancestry_integrity! method (thx Arthur Holstvoogd)

## Version 1.2.4 (2011-04-22)
* Prepended table names to column names in queries (thx raelik)
* Better check to see if acts_as_tree can be overloaded (thx jims)
* Performance inprovements (thx kueda)

## Version 1.2.3 (2010-10-28)
* Fixed error with determining ActiveRecord version
* Added option to specify :primary_key_format (thanks goes to rolftimmermans)

## Version 1.2.2 (2010-10-24)
* Fixed all deprecation warnings for rails 3.0.X
* Added :report option to check_ancestry_integrity!
* Changed ActiveRecord dependency to 2.2.2
* Tested and fixed for ruby 1.8.7 and 1.9.2
* Changed usage of update_attributes to update_attribute to allow ancestry column protection

## Version 1.2.0 (2009-11-07)
* Removed some duplication in has_ancestry
* Cleaned up plugin pattern according to http://yehudakatz.com/2009/11/12/better-ruby-idioms/
* Moved parts of ancestry into seperate files
* Made it possible to pass options into the arrange method
* Renamed acts_as_tree to has_ancestry
* Aliased has_ancestry as acts_as_tree if acts_as_tree is available
* Added subtree_of scope
* Updated ordered_by_ancestry scope to support Microsoft SQL Server
* Added empty hash as parameter to exists? calls for older ActiveRecord versions

## Version 1.1.4 (2009-11-07)
* Thanks to a patch from tom taylor, Ancestry now works with different primary keys

# Version 1.1.3 (2009-11-01)
* Fixed a pretty bad bug where several operations took far too many queries

## Version 1.1.2 (2009-10-29)
* Added validation for depth cache column
* Added STI support (reported broken)

## Version 1.1.1 (2009-10-28)
* Fixed some parentheses warnings that where reported
* Fixed a reported issue with arrangement
* Fixed issues with ancestors and path order on postgres
* Added ordered_by_ancestry scope (needed to fix issues)

## Version 1.1.0 (2009-10-22)
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

## Version 1.0.0 (2009-10-16)
* Initial version
* Tree building
* Tree navigation
* Integrity checking / restoration
* Arrangement
* Orphan strategies
* Subtree movement
* Named scopes
* Validations
