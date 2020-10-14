[![Build Status](https://travis-ci.org/stefankroes/ancestry.svg?branch=master)](https://travis-ci.org/stefankroes/ancestry) [![Coverage Status](https://coveralls.io/repos/stefankroes/ancestry/badge.svg)](https://coveralls.io/r/stefankroes/ancestry) [![Gitter](https://badges.gitter.im/Join+Chat.svg)](https://gitter.im/stefankroes/ancestry?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Security](https://hakiri.io/github/stefankroes/ancestry/master.svg)](https://hakiri.io/github/stefankroes/ancestry/master)

# Ancestry

Ancestry is a gem that allows the records of a Ruby on Rails
ActiveRecord model to be organised as a tree structure (or hierarchy). It employs
the materialised path pattern and exposes all the standard tree structure
relations (ancestors, parent, root, children, siblings, descendants), allowing all
of them to be fetched in a single SQL query. Additional features include STI
support, scopes, depth caching, depth constraints, easy migration from older
gems, integrity checking, integrity restoration, arrangement of
(sub)trees into hashes, and various strategies for dealing with orphaned
records.

NOTE:

- Ancestry 2.x supports Rails 4.1 and earlier
- Ancestry 3.x supports Rails 5.0 and 4.2
- Ancestry 4.0 only supports rails 5.0 and higher

# Installation

Follow these simple steps to apply Ancestry to any ActiveRecord model:

## Install

* Add to Gemfile:

```ruby
# Gemfile

gem 'ancestry'
```

* Install required gems:

```bash
$ bundle install
```


## Add ancestry column to your table
* Create migration:

```bash
$ rails g migration add_ancestry_to_[table] ancestry:string:index
```

*   Migrate your database:

```bash
$ rake db:migrate
```


## Add ancestry to your model
* Add to app/models/[model.rb]:

```ruby
# app/models/[model.rb]

class [Model] < ActiveRecord::Base
   has_ancestry
end
```

Your model is now a tree!

# Using acts_as_tree instead of has_ancestry

In version 1.2.0, the **acts_as_tree** method was **renamed to has_ancestry**
in order to allow usage of both the acts_as_tree gem and the ancestry gem in a
single application. The `acts_as_tree` method will continue to be supported in the future.

# Organising records into a tree

You can use the parent attribute to organise your records into a tree. If you
have the id of the record you want to use as a parent and don't want to fetch
it, you can also use parent_id. Like any virtual model attributes, parent and
parent_id can be set using parent= and parent_id= on a record or by including
them in the hash passed to new, create, create!, update_attributes and
update_attributes!. For example:

`TreeNode.create! :name => 'Stinky', :parent => TreeNode.create!(:name => 'Squeeky')`.

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
|`sibling_of?(node)`            |                                                     |                                 |

<sup id="fn1">1. [other root records are considered siblings]<a href="#ref1" title="Jump back to footnote 1.">↩</a></sup>

# `has_ancestry` options

The has_ancestry method supports the following options:

    :ancestry_column       Pass in a symbol to store ancestry in a different column
    :orphan_strategy       Instruct Ancestry what to do with children of a node that is destroyed:
                           :destroy   All children are destroyed as well (default)
                           :rootify   The children of the destroyed node become root nodes
                           :restrict  An AncestryException is raised if any children exist
                           :adopt     The orphan subtree is added to the parent of the deleted node
                                      If the deleted node is Root, then rootify the orphan subtree
    :cache_depth           Cache the depth of each node in the 'ancestry_depth' column (default: false)
                           If you turn depth_caching on for an existing model:
                           - Migrate: add_column [table], :ancestry_depth, :integer, :default => 0
                           - Build cache: TreeNode.rebuild_depth_cache!
    :depth_cache_column    Pass in a symbol to store depth cache in a different column
    :primary_key_format    Supply a regular expression that matches the format of your primary key
                           By default, primary keys only match integers ([0-9]+)
    :touch                 Instruct Ancestry to touch the ancestors of a node when it changes, to
                           invalidate nested key-based caches. (default: false)
    :counter_cache         Boolean whether to create counter cache column accessor. 
                           Default column name is `children_count`. 
                           Pass symbol to use different column name (default: false)

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

With depth caching enabled (see has_ancestry options), an additional five named
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

# STI support

To use with STI: create a STI inheritance hierarchy and build a tree from the different
classes/models. All Ancestry relations that were described above will return nodes of any model type. If
you do only want nodes of a specific subclass, a type condition is required.

# Arrangement

A subtree can be arranged into nested hashes for easy navigation after database retrieval.
`TreeNode.arrange` could, for instance, return:

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

The `arrange` method can work on a scoped class (`TreeNode.find_by(:name => 'Crunchy').subtree.arrange`),
and can take ActiveRecord find options. If you want ordered hashes, pass the order to the method instead of
the scope as follows:

`TreeNode.find_by(:name => 'Crunchy').subtree.arrange(:order => :name)`.

The `arrange_serializable` method returns the arranged nodes as a nested array of hashes. Order
can be passed in the same fashion as to the `arrange` method:
`TreeNode.arrange_serializable(:order => :name)` The result can easily be serialized to json with `to_json`
or other formats. You can also supply your own serialization logic with blocks.

Using `ActiveModel` serializers:

`TreeNode.arrange_serializable { |parent, children| MySerializer.new(parent, children: children) }`.

Or plain hashes:

```ruby
TreeNode.arrange_serializable do |parent, children|
  {
     my_id: parent.id,
     my_children: children
  }
end
```

# Sorting

The `sort_by_ancestry` class method: `TreeNode.sort_by_ancestry(array_of_nodes)` can be used
to sort an array of nodes as if traversing in preorder. (Note that since materialised path
trees do not support ordering within a rank, the order of siblings is
dependant upon their original array order.)

# Migrating from plugin that uses parent_id column

Most current tree plugins use a parent_id column (has_ancestry,
awesome_nested_set, better_nested_set, acts_as_nested_set). With Ancestry it is
easy to migrate from any of these plugins. To do so, use the
`build_ancestry_from_parent_ids!` method on your ancestry model.

<details>
<summary>Details</summary>

1.  Add ancestry column to your table
    *   Create migration: **rails g migration [add_ancestry_to_](table)
        ancestry:string**
    *   Add index to migration: **add_index [table], :ancestry** (UP) /
        **remove_index [table], :ancestry** (DOWN)
    *   Migrate your database: **rake db:migrate**


2.  Remove old tree gem and add in Ancestry to Gemfile
    *   See 'Installation' for more info on installing and configuring gems


3.  Change your model
    *   Remove any macros required by old plugin/gem from
        `[app/models/](model).rb`
    *   Add to `[app/models/](model).rb`: `has_ancestry`


4.  Generate ancestry columns
    *   In rails console: **[model].build_ancestry_from_parent_ids!**
    *   Make sure it worked ok: **[model].check_ancestry_integrity!**


5.  Change your code
    *   Most tree calls will probably work fine with ancestry
    *   Others must be changed or proxied
    *   Check if all your data is intact and all tests pass


6.  Drop parent_id column:
    *   Create migration: `rails g migration [remove_parent_id_from_](table)`
    *   Add to migration: `remove_column [table], :parent_id`
    *   Migrate your database: `rake db:migrate`
</details>

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

# Internals

Ancestry stores a path from the root to the parent for every node.
This is a variation on the materialised path database pattern.
It allows Ancestry to fetch any relation (siblings,
descendants, etc.) in a single SQL query without the complicated algorithms
and incomprehensibility associated with left and right values. Additionally,
any inserts, deletes and updates only affect nodes within the affected node's
own subtree.

In the example above, the `ancestry` column is created as a `string`. This puts a
limitation on the depth of the tree of about 40 or 50 levels. To increase the
maximum depth of the tree, increase the size of the `string` or use `text` to
remove the limitation entirely. Changing it to a text will however decrease
performance because an index cannot be put on the column in that case.

The materialised path pattern requires Ancestry to use a 'like' condition in
order to fetch descendants. The wild character (`%`) is on the right of the
query, so indexes should be used.

# Contributing and license

Question? Bug report? Faulty/incomplete documentation? Feature request? Please
post an issue on 'http://github.com/stefankroes/ancestry/issues'. Make sure
you have read the documentation and you have included tests and documentation
with any pull request.

Copyright (c) 2016 Stefan Kroes, released under the MIT license
