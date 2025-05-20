[![Gitter](https://badges.gitter.im/Join+Chat.svg)](https://gitter.im/stefankroes/ancestry?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

# Ancestry

## Overview

Ancestry is a gem that allows rails ActiveRecord models to be organized as
a tree structure (or hierarchy). It employs the materialized path pattern
which allows operations to be performed efficiently.

# Features

There are a few common ways of storing hierarchical data in a database:
materialized path, closure tree table, adjacency lists, nested sets, and adjacency list with recursive queries.

## Features from Materialized Path

- Store hierarchy in an easy to understand format. (e.g.: `/1/2/3/`)
- Store hierarchy in the original table with no additional tables.
- Single SQL queries for relations (`ancestors`, `parent`, `root`, `children`, `siblings`, `descendants`)
- Single query for creating records.
- Moving/deleting nodes only affect child nodes (rather than updating all nodes in the tree)

## Features from Ancestry gem Implementation

- relations are implemented as `scopes`
- `STI` support
- Arrangement of subtrees into hashes
- Multiple strategies for querying materialized_path
- Multiple strategies for dealing with orphaned records
- depth caching
- depth constraints
- counter caches
- Multiple strategies for moving nodes
- Easy migration from `parent_id` based gems
- Integrity checking
- Integrity restoration
- Most queries use indexes on `id` or `ancestry` column. (e.g.: `LIKE '#{ancestry}/%'`)

Since a Btree index has a limitation of 2704 characters for the `ancestry` column,
the maximum depth of an ancestry tree is 900 items at most. If ids are 4 digits long,
then the max depth is 540 items.

When using `STI` all classes are returned from the scopes unless you specify otherwise using `where(:type => "ChildClass")`.

## Supported Rails versions

- Ancestry 2.x supports Rails 4.1 and earlier
- Ancestry 3.x supports Rails 4.2 and 5.0
- Ancestry 4.x supports Rails 5.2 through 7.0
- Ancestry 5.0 supports Rails 6.0 and higher  
  Rails 5.2 with `update_strategy=ruby` is still being tested in 5.0.

# Installation

Follow these steps to apply Ancestry to any ActiveRecord model:

## Add to Gemfile

```ruby
# Gemfile

gem 'ancestry'
```

```bash
$ bundle install
```

## Add ancestry column to your table

```bash
$ rails g migration add_[ancestry]_to_[table] ancestry:string:index
```

```ruby
class AddAncestryToTable < ActiveRecord::Migration[6.1]
  def change
    change_table(:table) do |t|
      # postgres
      t.string "ancestry", collation: 'C', null: false
      t.index "ancestry"
      # mysql
      t.string "ancestry", collation: 'utf8mb4_bin', null: false
      t.index "ancestry"
    end
  end
end
```

There are additional options for the columns in [Ancestry Database Column](#ancestry-database-column) and
an explanation for `opclass` and `collation`.

```bash
$ rake db:migrate
```

## Configure ancestry defaults

```ruby
# config/initializers/ancestry.rb

# use the newer format
Ancestry.default_ancestry_format = :materialized_path2
# Ancestry.default_update_strategy = :sql
```

## Add ancestry to your model

```ruby
# app/models/[model.rb]

class [Model] < ActiveRecord::Base
   has_ancestry
end
```

Your model is now a tree!

# Organising records into a tree

You can use `parent_id` and `parent` to add a node into a tree. They can be
set as attributes or passed into methods like `new`, `create`, and `update`.

```ruby
TreeNode.create! :name => 'Stinky', :parent => TreeNode.create!(:name => 'Squeeky')
```

Children can be created through the children relation on a node: `node.children.create :name => 'Stinky'`.

# Tree Navigation

The node with the large border is the reference node (the node from which the navigation method is invoked.)
The yellow nodes are those returned by the method.

|                               |                                                     |                                 |
|:-:                            |:-:                                                  |:-:                              |
|**parent**                     |**root**<sup><a href="#fn1" id="ref1">1</a></sup>    |**ancestors**                    |
|![parent](/img/parent.png)     |![root](/img/root.png)                               |![ancestors](/img/ancestors.png) |
| nil for a root node           |self for a root node                                 |root..parent                     |
| `parent_id`                   |`root_id`                                            |`ancestor_ids`                   |
| `has_parent?`                 |`is_root?`                                           |`ancestors?`                     |
|`parent_of?`                   |`root_of?`                                           |`ancestor_of?`                   |
|**children**                   |**descendants**                                      |**indirects**                    |
|![children](/img/children.png) |![descendants](/img/descendants.png)                 |![indirects](/img/indirects.png) |
| `child_ids`                   |`descendant_ids`                                     |`indirect_ids`                   |
| `has_children?`               |                                                     |                                 |
| `child_of?`                   |`descendant_of?`                                     |`indirect_of?`                   |
|**siblings**                   |**subtree**                                          |**path**                         |
|![siblings](/img/siblings.png) |![subtree](/img/subtree.png)                         |![path](/img/path.png)           |
| includes self                 |self..indirects                                      |root..self                       |
|`sibling_ids`                  |`subtree_ids`                                        |`path_ids`                       |
|`has_siblings?`                |                                                     |                                 |
|`sibling_of?(node)`            |`in_subtree_of?`                                     |                                 |

When using `STI` all classes are returned from the scopes unless you specify otherwise using `where(:type => "ChildClass")`.

<sup id="fn1">1. [other root records are considered siblings]<a href="#ref1" title="Jump back to footnote 1.">↩</a></sup>

# has_ancestry options

The `has_ancestry` method supports the following options:

    :ancestry_column       Column name to store ancestry
                           'ancestry' (default)
    :ancestry_format       Format for ancestry column (see Ancestry Formats section):
                           :materialized_path   1/2/3, root nodes ancestry=nil (default)
                           :materialized_path2  /1/2/3/, root nodes ancestry=/ (preferred)
    :orphan_strategy       How to handle children of a destroyed node:
                           :destroy   All children are destroyed as well (default)
                           :rootify   The children of the destroyed node become root nodes
                           :restrict  An AncestryException is raised if any children exist
                           :adopt     The orphan subtree is added to the parent of the deleted node
                                      If the deleted node is Root, then rootify the orphan subtree
                           :none      skip this logic. (add your own `before_destroy`)
    :cache_depth           Cache the depth of each node: (See Depth Cache section)
                           false   Do not cache depth (default)
                           true    Cache depth in 'ancestry_depth'
                           String  Cache depth in the column referenced
    :primary_key_format    Regular expression that matches the format of the primary key:
                           '[0-9]+'            integer ids (default)
                           '[-A-Fa-f0-9]{36}'  UUIDs
    :touch                 Touch the ancestors of a node when it changes:
                           false  don't invalid nested key-based caches (default)
                           true   touch all ancestors of previous and new parents
    :counter_cache         Create counter cache column accessor:
                           false  don't store a counter cache (default)
                           true   store counter cache in `children_count`.
                           String name of column to store counter cache.
    :update_strategy       How to update descendants nodes:
                           :ruby  All descendants are updated using the ruby algorithm. (default)
                                  This triggers update callbacks for each descendant node
                           :sql   All descendants are updated using a single SQL statement.
                                  This strategy does not trigger update callbacks for the descendants.
                                  This strategy is available only for PostgreSql implementations

Legacy configuration using `acts_as_tree` is still available. Ancestry defers to `acts_as_tree` if that gem is installed.

# (Named) Scopes

The navigation methods return scopes instead of records, where possible. Additional ordering,
conditions, limits, etc. can be applied and the results can be retrieved, counted, or checked for existence:

```ruby
node.children.where(:name => 'Mary').exists?
node.subtree.order(:name).limit(10).each { ... }
node.descendants.count
```

A couple of class-level named scopes are included:

    roots                   Root nodes
    ancestors_of(node)      Ancestors of node, node can be either a record or an id
    children_of(node)       Children of node, node can be either a record or an id
    descendants_of(node)    Descendants of node, node can be either a record or an id
    indirects_of(node)      Indirect children of node, node can be either a record or an id
    subtree_of(node)        Subtree of node, node can be either a record or an id
    siblings_of(node)       Siblings of node, node can be either a record or an id

It is possible thanks to some convenient rails magic to create nodes through the children and siblings scopes:

    node.children.create
    node.siblings.create!
    TestNode.children_of(node_id).new
    TestNode.siblings_of(node_id).create

# Selecting nodes by depth

With depth caching enabled (see [has_ancestry options](#has_ancestry-options)), an additional five named
scopes can be used to select nodes by depth:

    before_depth(depth)     Return nodes that are less deep than depth (node.depth < depth)
    to_depth(depth)         Return nodes up to a certain depth (node.depth <= depth)
    at_depth(depth)         Return nodes that are at depth (node.depth == depth)
    from_depth(depth)       Return nodes starting from a certain depth (node.depth >= depth)
    after_depth(depth)      Return nodes that are deeper than depth (node.depth > depth)

Depth scopes are also available through calls to `descendants`,
`descendant_ids`, `subtree`, `subtree_ids`, `path` and `ancestors` (with relative depth).
Note that depth constraints cannot be passed to `ancestor_ids` or `path_ids` as both relations
can be fetched directly from the ancestry column without needing a query. Use
`ancestors(depth_options).map(&:id)` or `ancestor_ids.slice(min_depth..max_depth)` instead.

    node.ancestors(:from_depth => -6, :to_depth => -4)
    node.path.from_depth(3).to_depth(4)
    node.descendants(:from_depth => 2, :to_depth => 4)
    node.subtree.from_depth(10).to_depth(12)

# Arrangement

## `arrange`

A subtree can be arranged into nested hashes for easy navigation after database retrieval.

The resulting format is a hash of hashes

```ruby
{
  #<TreeNode id: 100018, name: "Stinky", ancestry: nil> => {
    #<TreeNode id: 100019, name: "Crunchy", ancestry: "100018"> => {
      #<TreeNode id: 100020, name: "Squeeky", ancestry: "100018/100019"> => {}
    },
    #<TreeNode id: 100021, name: "Squishy", ancestry: "100018"> => {}
  }
}
```

There are many ways to call `arrange`:

```ruby
TreeNode.find_by(:name => 'Crunchy').subtree.arrange
TreeNode.find_by(:name => 'Crunchy').subtree.arrange(:order => :name)
```

## `arrange_serializable`

If a hash of arrays is preferred, `arrange_serializable` can be used. The results
work well with `to_json`.

```ruby
TreeNode.arrange_serializable(:order => :name)
# use an active model serializer
TreeNode.arrange_serializable { |parent, children| MySerializer.new(parent, children: children) }
TreeNode.arrange_serializable do |parent, children|
  {
     my_id: parent.id,
     my_children: children
  }
end
```

# Sorting

The `sort_by_ancestry` class method: `TreeNode.sort_by_ancestry(array_of_nodes)` can be used
to sort an array of nodes as if traversing in preorder. (Note that since materialized path
trees do not support ordering within a rank, the order of siblings is
dependant upon their original array order.)


# Eager Loading

Ancestry provides advanced eager loading capabilities to improve performance when working with tree structures. These methods help you avoid N+1 query problems by loading entire tree structures in just a few database queries.

## Loading Tree Relationships Efficiently

The following methods are available for eager loading:

```ruby
# Load a complete tree with parent-child relationships in a single query
TreeNode.with_tree

# Load nodes with all their ancestors
TreeNode.with_ancestors

# Load nodes with all their descendants
TreeNode.with_descendants

# Load nodes with just their children
TreeNode.with_children

# Load nodes with just their parents
TreeNode.with_parent

# Load nodes with their siblings
TreeNode.with_siblings

# Load nodes with their indirect descendants (not direct children)
TreeNode.with_indirects

# Load nodes with their entire subtree (self + descendants)
TreeNode.with_subtree
```

## Combining with Other Eager Loading

You can combine Ancestry's eager loading with ActiveRecord's standard eager loading:

```ruby
# Load categories with their ancestors and associated products
Category.with_ancestors.includes(:products)

# Load a complete organization chart with associated user data
Department.with_tree.includes(:manager, :employees)
```

## Performance Benefits

Eager loading significantly improves performance in the following scenarios:

1. **Rendering hierarchical menus or navigation**: Load the entire tree structure in one query
2. **Displaying category trees**: Efficiently load and display all categories and subcategories
3. **Organization charts**: Render complete org charts without additional queries
4. **Nested comment systems**: Load threaded comments efficiently

## Automatic Preloading

For even greater convenience, you can enable automatic preloading of tree relationships by adding the `preload: true` option to your model definition:

```ruby
class Category < ApplicationRecord
  has_ancestry preload: true
end
```

With this option enabled, all queries against the model will automatically preload the entire tree structure without requiring explicit calls to the eager loading methods:

```ruby
# This automatically loads the entire tree structure
category = Category.find(123)

# These won't trigger additional database queries
category.children    # No database query
category.ancestors   # No database query
category.parent      # No database query
category.descendants # No database query
```

### Benefits of Automatic Preloading

- **Simplified Code**: No need to remember to call eager loading methods
- **Eliminates N+1 Queries**: Automatically ensures efficient tree traversal
- **Seamless Integration**: Works with existing code without requiring changes

### Considerations

- For very large trees, automatic preloading might load more data than necessary for specific operations
- Increases memory usage since entire tree structures are loaded upfront
- Recommended for medium-sized trees or when frequently traversing tree relationships

## Example Usage

```ruby
# Load a complete tree and display it hierarchically
tree_nodes = TreeNode.with_tree.arrange

# Access relationships without triggering additional queries
node = TreeNode.with_descendants.find(id)
node.children    # No additional query - uses cached data
node.descendants # Still no additional query

# Efficiently build a hierarchical menu
menu_items = MenuItem.with_tree
menu_items.each do |item|
  # Access item.children without additional queries
end
```

# Ancestry Database Column

## Collation Indexes

Sorry, using collation or index operator classes makes this a little complicated. The
root of the issue is that in order to use indexes, the ancestry column needs to
compare strings using ascii rules.

It is well known that `LIKE '/1/2/%'` will use an index because the wildcard (i.e.: `%`)
is on the right hand side of the `LIKE`. While that is true for ascii strings, it is not
necessarily true for unicode. Since ancestry only uses ascii characters, telling the database
this constraint will optimize the `LIKE` statements.

## Collation Sorting

As of 2018, standard unicode collation ignores punctuation for sorting. This ignores
the ancestry delimiter (i.e.: `/`) and returns data in the wrong order. The exception
being Postgres on a mac, which ignores proper unicode collation and instead uses
ISO-8859-1 ordering (read: ascii sorting).

Using the proper column storage and indexes will ensure that data is returned from the
database in the correct order. It will also ensure that developers on Mac or Windows will
get the same results as linux production servers, if that is your setup.

## Migrating Collation

If you are reading this and want to alter your table to add collation to an existing column,
remember to drop existing indexes on the `ancestry` column and recreate them.

## ancestry_format materialized_path and nulls

If you are using the legacy `ancestry_format` of `:materialized_path`, then you need to the
column to allow `nulls`. Change the column create accordingly: `null: true`.

Chances are, you can ignore this section as you most likely want to use `:materialized_path2`.

## Postgres Storage Options

### ascii field collation

The currently suggested way to create a postgres field is using `'C'` collation:

```ruby
t.string "ancestry", collation: 'C', null: false
t.index "ancestry"
```

### ascii index

If you need to use a standard collation (e.g.: `en_US`), then use an ascii index:

```ruby
t.string "ancestry", null: false
t.index  "ancestry", opclass: :varchar_pattern_ops
```

This option is mostly there for users who have an existing ancestry column and are more
comfortable tweaking indexes rather than altering the ancestry column.

### binary column

When the column is binary, the database doesn't convert strings using locales.
Rails will convert the strings and send byte arrays to the database.
At this time, this option is not suggested. The sql is not as readable, and currently
this does not support the `:sql` update_strategy.

```ruby
t.binary "ancestry", limit: 3000, null: false
t.index  "ancestry"
```
You may be able to alter the database to gain some readability:

```SQL
ALTER DATABASE dbname SET bytea_output to 'escape';
```

## MySQL Storage options

### ascii field collation

The currently suggested way to create a MySQL field is using `'utf8mb4_bin'` collation:

```ruby
t.string "ancestry", collation: 'utf8mb4_bin', null: false
t.index "ancestry"
```

### binary collation

Collation of `binary` acts much the same way as the `binary` column:

```ruby
t.string "ancestry", collate: 'binary', limit: 3000, null: false
t.index  "ancestry"
```

### binary column

```ruby
t.binary "ancestry", limit: 3000, null: false
t.index  "ancestry"
```

### ascii character set

MySQL supports per column character sets. Using a character set of `ascii` will
set this up.

```SQL
ALTER TABLE table
  ADD COLUMN ancestry VARCHAR(2700) CHARACTER SET ascii;
```

# Ancestry Formats

You can choose from 2 ancestry formats:

- `:materialized_path` - legacy format (currently the default for backwards compatibility reasons)
- `:materialized_path2` - newer format. Use this if it is a new column

```
:materialized_path    1/2/3,  root nodes ancestry=nil
    descendants SQL: ancestry LIKE '1/2/3/%' OR ancestry = '1/2/3'
:materialized_path2  /1/2/3/, root nodes ancestry=/
    descendants SQL: ancestry LIKE '/1/2/3/%'
```

If you are unsure, choose `:materialized_path2`. It allows a not NULL column,
faster descendant queries, has one less `OR` statement in the queries, and
the path can be formed easily in a database query for added benefits.

There is more discussion in [Internals](#internals) or [Migrating ancestry format](#migrate-ancestry-format)
For migrating from `materialized_path` to `materialized_path2` see [Ancestry Column](#ancestry-column)

## Migrating Ancestry Format

To migrate from `materialized_path` to `materialized_path2`:

```ruby
klass = YourModel
# set all child nodes
klass.where.not(klass.arel_table[klass.ancestry_column].eq(nil)).update_all("#{klass.ancestry_column} = CONCAT('#{klass.ancestry_delimiter}', #{klass.ancestry_column}, '#{klass.ancestry_delimiter}')")
# set all root nodes
klass.where(klass.arel_table[klass.ancestry_column].eq(nil)).update_all("#{klass.ancestry_column} = '#{klass.ancestry_root}'")

change_column_null klass.table_name, klass.ancestry_column, false
```

# Migrating from plugin that uses parent_id column

It should be relatively simple to migrating from a plugin that uses a `parent_id`
column, (e.g.: `awesome_nested_set`, `better_nested_set`, `acts_as_nested_set`).

When running the installation steps, also remove the old gem from your `Gemfile`,
and remove the old gem's macros from the model.

Then populate the `ancestry` column from rails console:

```ruby
Model.build_ancestry_from_parent_ids!
# Model.rebuild_depth_cache!
Model.check_ancestry_integrity!
```

It is time to run your code. Most tree methods should work fine with ancestry
and hopefully your tests only require a few minor tweaks to get up and running.

Once you are happy with how your app is running, remove the old `parent_id` column:

```bash
$ rails g migration remove_parent_id_from_[table]
```

```ruby
class RemoveParentIdFromToTable < ActiveRecord::Migration[6.1]
  def change
    remove_column "table", "parent_id", type: :integer
  end
end
```

```bash
$ rake db:migrate
```

# Depth cache

## Depth Cache Migration

To add depth_caching to an existing model:

## Add column

```ruby
class AddDepthCacheToTable < ActiveRecord::Migration[6.1]
  def change
    change_table(:table) do |t|
      t.integer "ancestry_depth", default: 0
    end
  end
end
```

## Add ancestry to your model

```ruby
# app/models/[model.rb]

class [Model] < ActiveRecord::Base
   has_ancestry cache_depth: true
end
```

## Update existing values

Add a custom script or run from rails console.
Some use migrations, but that can make the migration suite fragile. The command of interest is:

```ruby
Model.rebuild_depth_cache!
```

# Running Tests

```bash
git clone git@github.com:stefankroes/ancestry.git
cd ancestry
cp test/database.example.yml test/database.yml
bundle
appraisal install
# all tests
appraisal rake test
# single test version (sqlite and rails 5.0)
appraisal sqlite3-ar-50 rake test
```

# Contributing and license

Question? Bug report? Faulty/incomplete documentation? Feature request? Please
post an issue on 'http://github.com/stefankroes/ancestry/issues'. Make sure
you have read the documentation and you have included tests and documentation
with any pull request.

Copyright (c) 2016 Stefan Kroes, released under the MIT license
