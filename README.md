[![CI](https://github.com/stefankroes/ancestry/actions/workflows/run_test_suite.yml/badge.svg)](https://github.com/stefankroes/ancestry/actions/workflows/run_test_suite.yml)

# Ancestry

> **Reading these docs on GitHub?** The `master` branch reflects bleeding-edge
> development and may describe features not yet released. Use the branch
> selector above to switch to the [tag](https://github.com/stefankroes/ancestry/tags)
> matching the version of the gem you have installed.

## Overview

Ancestry is a gem that allows rails ActiveRecord models to be organized as
a tree structure (or hierarchy). It employs the materialized path pattern —
one column, no extra tables, single-query reads. [Benchmarks](https://github.com/kbrock/tree-bench)
show it outperforms alternatives on most single-node operations.

# Features

Ancestry uses the **materialized path** pattern: each record stores its ancestor
chain in a single column (e.g. `1/2/3/`). No additional tables needed.

- Single btree indexed query for [any relation](#tree-navigation): `ancestors`, `descendants`, `siblings`, `children`, `leaves`. [Benchmarks](https://github.com/kbrock/tree-bench)
- No extra tables — hierarchy lives in a column on your existing table
- Moving a node only updates its descendants, not the whole tree
- **New:** Real ActiveRecord [associations](#cached-columns) (`belongs_to :parent`, `has_many :children`) with eager loading
- [Multiple orphan strategies](#has_ancestry-options) for handling deleted nodes
- [Depth caching and constraints](#selecting-nodes-by-depth), counter caches
- [Integrity checking and restoration](CONFIGURATION.md)
- STI support — all classes returned from scopes unless filtered with `where(type: "ChildClass")`

# Installation

Follow these steps to apply Ancestry to any ActiveRecord model:

```ruby
# Gemfile
gem 'ancestry'
```

```bash
$ bundle install
$ rails g migration add_ancestry_to_[table]
```

```ruby
class AddAncestryToTable < ActiveRecord::Migration[7.0]
  def change
    change_table(:table) do |t|
      t.ancestry
      # t.ancestry format: :materialized_path3, cache_depth: true, parent: true, counter_cache: true
    end
  end
end
```

The `t.ancestry` helper creates the column with the correct type, collation, and indexes for your database. It accepts options for [cached columns](#cached-columns) and [ancestry formats](#ancestry-formats).

For manual column setup or advanced options, see [Ancestry Database Column](#ancestry-database-column).

```bash
$ rake db:migrate
```

## Configure ancestry defaults

```ruby
# config/initializers/ancestry.rb (optional)

# use the newer format
Ancestry.default_ancestry_format = :materialized_path3
# Ancestry.default_update_strategy = :sql
# Ancestry.primary_key_format = :uuid
```

You can set some default ancestry options, or add them to each `has_ancestry` call in your models.

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

|                               |                                                     |                                 |                             |
|:-:                            |:-:                                                  |:-:                              |:-:                          |
|**parent**                     |**ancestors**                                        |**path**                         |**root**                     |
|![parent](/img/parent.png)     |![ancestors](/img/ancestors.png)                     |![path](/img/path.png)           |![root](/img/root.png)       |
| nil for a root node           | root..parent                                        | root..self                      | self for a root node        |
| `parent_id`                   | `ancestor_ids`                                      | `path_ids`                      | `root_id`                   |
| `has_parent?`                 |                                                     |                                 | `is_root?`                  |
| `parent_of?`                  | `ancestor_of?`                                      |                                 | `root_of?`                  |
|**children**                   |**descendants**                                      |**subtree**                      |**leaves**                   |
|![children](/img/children.png) |![descendants](/img/descendants.png)                 |![subtree](/img/subtree.png)     |![leaves](/img/leaves.png)   |
| direct children               | all below                                           | self + descendants              | descendants with no children|
| `child_ids`                   | `descendant_ids`                                    | `subtree_ids`                   | `leaf_ids`                  |
| `has_children?`               |                                                     |                                 | `is_leaf?`                  |
| `child_of?`                   | `descendant_of?`                                    | `in_subtree_of?`                |                             |
|**siblings**<sup><a href="#fn1" id="ref1">1</a></sup>                                |**indirects**                    |                             |
|![siblings](/img/siblings.png) |![indirects](/img/indirects.png)                     |                                 |                             |
| excludes self                 | descendants - children                              |                                 |                             |
| `sibling_ids`                 | `indirect_ids`                                      |                                 |                             |
| `has_siblings?`               |                                                     |                                 |                             |
| `sibling_of?`                 | `indirect_of?`                                      |                                 |                             |

When using `STI` all classes are returned from the scopes unless you specify otherwise using `where(:type => "ChildClass")`.

<sup id="fn1">1. [root nodes are siblings of each other]<a href="#ref1" title="Jump back to footnote 1.">↩</a></sup>

# has_ancestry options

The `has_ancestry` method supports the following options:

    :ancestry_column       Column name to store ancestry
                           'ancestry' (default)
    :ancestry_format       Format for ancestry column (see Ancestry Formats section):
                           :materialized_path   1/2/3, root nodes ancestry=nil (default)
                           :materialized_path2  /1/2/3/, root nodes ancestry=/ (preferred)
                           :ltree               1.2.3, root nodes ancestry='' (PostgreSQL only)
                           :array               {1,2,3}, root nodes ancestry={} (PostgreSQL only)
    :orphan_strategy       How to handle children of a destroyed node:
                           :destroy   All children are destroyed as well (default)
                           :rootify   The children of the destroyed node become root nodes
                           :restrict  An AncestryException is raised if any children exist
                           :adopt     The orphan subtree is added to the parent of the deleted node
                                      If the deleted node is Root, then rootify the orphan subtree
                           :none      skip this logic. (add your own `before_destroy`)
    :cache_depth           Cache the depth (number of ancestors) in a column: (See Cached Columns)
                           false    Do not cache depth (default)
                           true     Cache depth in 'ancestry_depth'
                           :virtual Use a database generated column
                           String   Cache depth in the column referenced
    :parent                Store the parent id in a column: (See Cached Columns)
                           false    Do not store parent id (default)
                           true     Cache parent id in 'parent_id' and define
                                    belongs_to :parent and has_many :children associations
                           :virtual Use a database generated column with associations
    :root                  Store the root id in a column: (See Cached Columns)
                           false    Do not store root id (default)
                           true     Cache root id in 'root_id' and define
                                    belongs_to :root association
                           :virtual Use a database generated column with association
    :primary_key_format    Format of the primary key:
                           :integer  integer ids (default)
                           :uuid     UUIDs
                           :string   alphanumeric string ids
    :touch                 Touch the ancestors of a node when it changes:
                           false  don't invalid nested key-based caches (default)
                           true   touch all ancestors of previous and new parents
    :counter_cache         Cache the number of children in a column:
                           false  Do not cache child count (default)
                           true   Cache child count in 'children_count'
                           String Cache child count in the column referenced
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


# Ancestry Database Column

The `t.ancestry` migration helper handles column type, collation, and indexes automatically.
For most applications, `t.ancestry` is all you need.

For manual column setup, database-specific collation options, and migrating collation on
existing columns, see [Configuration Reference](CONFIGURATION.md).

# Ancestry Formats

You can choose from the following ancestry formats:

- `:materialized_path` - legacy format (default for backwards compatibility)
- `:materialized_path2` - recommended for new columns
- `:materialized_path3` - like mp2 but root is `""` instead of `"/"`
- `:ltree` - PostgreSQL ltree type with GiST indexing

If you are unsure, choose `:materialized_path2`. It allows a `NOT NULL` column and
faster descendant queries (one less `OR` condition).

For PostgreSQL users who want native indexing, `:ltree` avoids string
parsing and collation issues entirely:

```ruby
# ltree — GiST-indexed <@ operator
enable_extension 'ltree'
create_table :tree_nodes do |t|
  t.ancestry format: :ltree
end
```

For detailed format comparison, migration between formats, and database-specific
column options, see [Configuration Reference](CONFIGURATION.md#ancestry-formats).

# Supported Rails Versions

| Ancestry | Rails              |
|----------|---------------------|
| 2.x      | 4.1 and earlier     |
| 3.x      | 4.2 – 5.0          |
| 4.x      | 5.2 – 7.0          |
| 5.x      | 6.0 – 8.1          |
| 6.x      | 7.0 – 8.1          |

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

# See also

Other Ruby tree gems, each with different tradeoffs:

- [acts_as_list](https://github.com/brendon/acts_as_list) — sortable lists with position column
- [acts_as_tree](https://github.com/amerine/acts_as_tree) — simple adjacency list (parent_id only)
- [awesome_nested_set](https://github.com/collectiveidea/awesome_nested_set) — nested set pattern (lft/rgt columns), fast subtree queries
- [closure_tree](https://github.com/ClosureTree/closure_tree) — closure table pattern (separate hierarchy table), fast reads
- [ltree_hierarchy](https://github.com/cfabianski/ltree_hierarchy) - Postgres ltree implementation
- [parentry](https://github.com/hasghari/parentry) - ltree and array implementation of ancestry.
- [pg_ltree](https://github.com/sjke/pg_ltree) - Postgres ltree implementation

# Contributing and license

Question? Bug report? Faulty/incomplete documentation? Feature request? Please
post an issue on 'http://github.com/stefankroes/ancestry/issues'. Make sure
you have read the documentation and you have included tests and documentation
with any pull request.

Copyright (c) 2016 Stefan Kroes, released under the MIT license
