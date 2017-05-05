[![Build Status](https://travis-ci.org/stefankroes/ancestry.svg?branch=master)](https://travis-ci.org/stefankroes/ancestry) [![Coverage Status](https://coveralls.io/repos/stefankroes/ancestry/badge.svg)](https://coveralls.io/r/stefankroes/ancestry) [![Gitter](https://badges.gitter.im/Join+Chat.svg)](https://gitter.im/stefankroes/ancestry?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge) [![Security](https://hakiri.io/github/stefankroes/ancestry/master.svg)](https://hakiri.io/github/stefankroes/ancestry/master)

# Ancestry

Ancestry is a gem/plugin that allows the records of a Ruby on Rails
ActiveRecord model to be organised as a tree structure (or hierarchy). It uses
a single, intuitively formatted database column, using a variation on the
materialised path pattern. It exposes all the standard tree structure
relations (ancestors, parent, root, children, siblings, descendants) and all
of them can be fetched in a single SQL query. Additional features are STI
support, scopes, depth caching, depth constraints, easy migration from older
plugins/gems, integrity checking, integrity restoration, arrangement of
(sub)tree into hashes and different strategies for dealing with orphaned
records.

# Installation

To apply Ancestry to any ActiveRecord model, follow these simple steps:

## Install
### Rails 2
*   See 1-3-stable branch

### Rails 3 and 4
*   Add to Gemfile:
        # Gemfile

        gem 'ancestry'

*   Install required gems:
        $ bundle install


## Add ancestry column to your table
*   Create migration:
        $ rails g migration add_ancestry_to_[table] ancestry:string

*   Add index to migration:
        # db/migrate/[date]_add_ancestry_to_[table].rb

        class AddAncestryTo[Table] < ActiveRecord::Migration
           # Rails 4 Syntax
           def change
              add_column [table], :ancestry, :string
              add_index [table], :ancestry
           end

           # Rails 3 Syntax
           def up
              add_column [table], :ancestry, :string
              add_index [table], :ancestry
           end

           def down
              remove_column [table], :ancestry
              remove_index [table], :ancestry
           end

*   Migrate your database:
        $ rake db:migrate


## Add ancestry to your model
*   Add to [app/models/](model).rb:
        # app/models/[model.rb]

        class [Model] < ActiveRecord::Base
           has_ancestry
        end


Your model is now a tree!

# Using acts_as_tree instead of has_ancestry

In version 1.2.0 the **acts_as_tree** method was **renamed to has_ancestry**
in order to allow usage of both the acts_as_tree gem and the ancestry gem in a
single application. To not break backwards compatibility, the has_ancestry
method is aliased with acts_as_tree if ActiveRecord::Base does not respond to
acts_as_tree. acts_as_tree will continue to be supported in the future as I
personally prefer it.

# Organising records into a tree

You can use the parent attribute to organise your records into a tree. If you
have the id of the record you want to use as a parent and don't want to fetch
it, you can also use parent_id. Like any virtual model attributes, parent and
parent_id can be set using parent= and parent_id= on a record or by including
them in the hash passed to new, create, create!, update_attributes and
update_attributes!. For example:

    TreeNode.create! :name => 'Stinky', :parent => TreeNode.create!(:name => 'Squeeky')

You can also create children through the children relation on a node:

    node.children.create :name => 'Stinky'

# Navigating your tree

To navigate an Ancestry model, use the following methods on any instance /
record:

    parent           Returns the parent of the record, nil for a root node
    parent_id        Returns the id of the parent of the record, nil for a root node
    root             Returns the root of the tree the record is in, self for a root node
    root_id          Returns the id of the root of the tree the record is in
    root?, is_root?  Returns true if the record is a root node, false otherwise
    ancestor_ids     Returns a list of ancestor ids, starting with the root id and ending with the parent id
    ancestors        Scopes the model on ancestors of the record
    path_ids         Returns a list the path ids, starting with the root id and ending with the node's own id
    path             Scopes model on path records of the record
    children         Scopes the model on children of the record
    child_ids        Returns a list of child ids
    has_children?    Returns true if the record has any children, false otherwise
    is_childless?    Returns true is the record has no children, false otherwise
    siblings         Scopes the model on siblings of the record, the record itself is included*
    sibling_ids      Returns a list of sibling ids
    has_siblings?    Returns true if the record's parent has more than one child
    is_only_child?   Returns true if the record is the only child of its parent
    descendants      Scopes the model on direct and indirect children of the record
    descendant_ids   Returns a list of a descendant ids
    subtree          Scopes the model on descendants and itself
    subtree_ids      Returns a list of all ids in the record's subtree
    depth            Return the depth of the node, root nodes are at depth 0

*   If the record is a root, other root records are considered siblings


# Options for has_ancestry

The has_ancestry methods supports the following options:

    :ancestry_column       Pass in a symbol to store ancestry in a different column
    :orphan_strategy       Instruct Ancestry what to do with children of a node that is destroyed:
                           :destroy   All children are destroyed as well (default)
                           :rootify   The children of the destroyed node become root nodes
                           :restrict  An AncestryException is raised if any children exist
                           :adopt     The orphan subtree is added to the parent of the deleted node.
                                      If the deleted node is Root, then rootify the orphan subtree.
    :cache_depth           Cache the depth of each node in the 'ancestry_depth' column (default: false)
                           If you turn depth_caching on for an existing model:
                           - Migrate: add_column [table], :ancestry_depth, :integer, :default => 0
                           - Build cache: TreeNode.rebuild_depth_cache!
    :depth_cache_column    Pass in a symbol to store depth cache in a different column
    :primary_key_format    Supply a regular expression that matches the format of your primary key.
                           By default, primary keys only match integers ([0-9]+).
    :touch                 Instruct Ancestry to touch the ancestors of a node when it changes, to
                           invalidate nested key-based caches. (default: false)

# (Named) Scopes

Where possible, the navigation methods return scopes instead of records, this
means additional ordering, conditions, limits, etc. can be applied and that
the result can be either retrieved, counted or checked for existence. For
example:

    node.children.exists?(:name => 'Mary')
    node.subtree.all(:order => :name, :limit => 10).each do; ...; end
    node.descendants.count

For convenience, a couple of named scopes are included at the class level:

    roots                   Root nodes
    ancestors_of(node)      Ancestors of node, node can be either a record or an id
    children_of(node)       Children of node, node can be either a record or an id
    descendants_of(node)    Descendants of node, node can be either a record or an id
    subtree_of(node)        Subtree of node, node can be either a record or an id
    siblings_of(node)       Siblings of node, node can be either a record or an id

Thanks to some convenient rails magic, it is even possible to create nodes
through the children and siblings scopes:

    node.children.create
    node.siblings.create!
    TestNode.children_of(node_id).new
    TestNode.siblings_of(node_id).create

# Selecting nodes by depth

When depth caching is enabled (see has_ancestry options), five more named
scopes can be used to select nodes on their depth:

    before_depth(depth)     Return nodes that are less deep than depth (node.depth < depth)
    to_depth(depth)         Return nodes up to a certain depth (node.depth <= depth)
    at_depth(depth)         Return nodes that are at depth (node.depth == depth)
    from_depth(depth)       Return nodes starting from a certain depth (node.depth >= depth)
    after_depth(depth)      Return nodes that are deeper than depth (node.depth > depth)

The depth scopes are also available through calls to descendants,
descendant_ids, subtree, subtree_ids, path and ancestors. In this case, depth
values are interpreted relatively. Some examples:

    node.subtree(:to_depth => 2)      Subtree of node, to a depth of node.depth + 2 (self, children and grandchildren)
    node.subtree.to_depth(5)          Subtree of node to an absolute depth of 5
    node.descendants(:at_depth => 2)  Descendant of node, at depth node.depth + 2 (grandchildren)
    node.descendants.at_depth(10)     Descendants of node at an absolute depth of 10
    node.ancestors.to_depth(3)        The oldest 4 ancestors of node (its root and 3 more)
    node.path(:from_depth => -2)      The node's grandparent, parent and the node itself

    node.ancestors(:from_depth => -6, :to_depth => -4)
    node.path.from_depth(3).to_depth(4)
    node.descendants(:from_depth => 2, :to_depth => 4)
    node.subtree.from_depth(10).to_depth(12)

Please note that depth constraints cannot be passed to ancestor_ids and
path_ids. The reason for this is that both these relations can be fetched
directly from the ancestry column without performing a database query. It
would require an entirely different method of applying the depth constraints
which isn't worth the effort of implementing. You can use
ancestors(depth_options).map(&:id) or ancestor_ids.slice(min_depth..max_depth)
instead.

# STI support

Ancestry works fine with STI. Just create a STI inheritance hierarchy and
build an Ancestry tree from the different classes/models. All Ancestry
relations that where described above will return nodes of any model type. If
you do only want nodes of a specific subclass you'll have to add a condition
on type for that.

# Arrangement

Ancestry can arrange an entire subtree into nested hashes for easy navigation
after retrieval from the database.  TreeNode.arrange could for example return:

    { #<TreeNode id: 100018, name: "Stinky", ancestry: nil>
      => { #<TreeNode id: 100019, name: "Crunchy", ancestry: "100018">
        => { #<TreeNode id: 100020, name: "Squeeky", ancestry: "100018/100019">
          => {}
        }
      }
    }

The arrange method also works on a scoped class, for example:

    TreeNode.find_by_name('Crunchy').subtree.arrange

The arrange method takes ActiveRecord find options. If you want your hashes to
be ordered, you should pass the order to the arrange method instead of to the
scope. This also works for Ruby 1.8 since an OrderedHash is returned. For
example:

    TreeNode.find_by_name('Crunchy').subtree.arrange(:order => :name)

To get the arranged nodes as a nested array of hashes for serialization:

    TreeNode.arrange_serializable

    [
      {
        "ancestry" => nil, "id" => 1, "children" => [
          { "ancestry" => "1", "id" => 2, "children" => [] }
        ]
      }
    ]

You can also supply your own serialization logic using blocks:

For example, using Active Model Serializers:

    TreeNode.arrange_serializable do |parent, children|
      MySerializer.new(parent, children: children)
    end

Or plain hashes:

    TreeNode.arrange_serializable do |parent, children|
      {
         my_id: parent.id
         my_children: children
      }
    end

The result of arrange_serializable can easily be serialized to json with
'to_json', or some other format:

    TreeNode.arrange_serializable.to_json

You can also pass the order to the arrange_serializable method just as you can
pass it to the arrange method:

    TreeNode.arrange_serializable(:order => :name)

# Sorting

If you just want to sort an array of nodes as if you were traversing them in
preorder, you can use the sort_by_ancestry class method:

    TreeNode.sort_by_ancestry(array_of_nodes)

Note that since materialised path trees don't support ordering within a rank,
the order of siblings depends on their order in the original array.

# Migrating from plugin that uses parent_id column

Most current tree plugins use a parent_id column (has_ancestry,
awesome_nested_set, better_nested_set, acts_as_nested_set). With ancestry its
easy to migrate from any of these plugins, to do so, use the
build_ancestry_from_parent_ids! method on your ancestry model. These steps
provide a more detailed explanation:

1.  Add ancestry column to your table
    *   Create migration: **rails g migration [add_ancestry_to_](table)
        ancestry:string**
    *   Add index to migration: **add_index [table], :ancestry** (UP) /
        **remove_index [table], :ancestry** (DOWN)
    *   Migrate your database: **rake db:migrate**


2.  Remove old tree plugin or gem and add in Ancestry
    *   Remove plugin: rm -Rf vendor/plugins/[old plugin]
    *   Remove gem config line from environment.rb: config.gem [old gem]
    *   Add Ancestry to environment.rb: config.gem :ancestry
    *   See 'Installation' for more info on installing and configuring gems


3.  Change your model
    *   Remove any macros required by old plugin/gem from
        [app/models/](model).rb
    *   Add to [app/models/](model).rb: **has_ancestry**


4.  Generate ancestry columns
    *   In './script.console': **[model].build_ancestry_from_parent_ids!**
    *   Make sure it worked ok: **[model].check_ancestry_integrity!**


5.  Change your code
    *   Most tree calls will probably work fine with ancestry
    *   Others must be changed or proxied
    *   Check if all your data is intact and all tests pass


6.  Drop parent_id column:
    *   Create migration: **rails g migration
        [remove_parent_id_from_](table)**
    *   Add to migration: **remove_column [table], :parent_id** (UP) /
        **add_column [table], :parent_id, :integer** (DOWN)
    *   Migrate your database: **rake db:migrate**



# Integrity checking and restoration

I don't see any way Ancestry tree integrity could get compromised without
explicitly setting cyclic parents or invalid ancestry and circumventing
validation with update_attribute, if you do, please let me know.

Ancestry includes some methods for detecting integrity problems and restoring
integrity just to be sure. To check integrity use:
[Model].check_ancestry_integrity!. An AncestryIntegrityException will be
raised if there are any problems. You can also specify :report => :list to
return an array of exceptions or :report => :echo to echo any error messages.
To restore integrity use: [Model].restore_ancestry_integrity!.

For example, from IRB:

    >> stinky = TreeNode.create :name => 'Stinky'
    $  #<TreeNode id: 1, name: "Stinky", ancestry: nil>
    >> squeeky = TreeNode.create :name => 'Squeeky', :parent => stinky
    $  #<TreeNode id: 2, name: "Squeeky", ancestry: "1">
    >> stinky.update_attribute :parent, squeeky
    $  true
    >> TreeNode.all
    $  [#<TreeNode id: 1, name: "Stinky", ancestry: "1/2">, #<TreeNode id: 2, name: "Squeeky", ancestry: "1/2/1">]
    >> TreeNode.check_ancestry_integrity!
    !! Ancestry::AncestryIntegrityException: Conflicting parent id in node 1: 2 for node 1, expecting nil
    >> TreeNode.restore_ancestry_integrity!
    $  [#<TreeNode id: 1, name: "Stinky", ancestry: 2>, #<TreeNode id: 2, name: "Squeeky", ancestry: nil>]

Additionally, if you think something is wrong with your depth cache:

    >> TreeNode.rebuild_depth_cache!

# Tests

The Ancestry gem comes with a unit test suite consisting of about 1900
assertions in about 50 tests. It takes about 10 seconds to run on sqlite. It
is run against three databases (sqlite3, mysql and postgresql) and four
versions of Activerecord (3.0, 3.1, 3.2 and 4.0) using Appraisals. To run it
yourself:
*   Check out the repository from GitHub
*   Copy test/database.example.yml to test/database.yml
*   Run `bundle`
*   Run `appraisal install`
*   Run `appraisal rake test`


You can also run against a specific database and specific version of
Activerecord:
*   Run the above commands, except for the last one
*   Run `appraisal sqlite3-ar-32 rake test` (to test against sqlite3 and
    Activerecord 3.2)


# Internals

As can be seen in the previous section, Ancestry stores a path from the root
to the parent for every node. This is a variation on the materialised path
database pattern. It allows Ancestry to fetch any relation (siblings,
descendants, etc.) in a single SQL query without the complicated algorithms
and incomprehensibility associated with left and right values. Additionally,
any inserts, deletes and updates only affect nodes within the affected node's
own subtree.

In the example above, the ancestry column is created as a string. This puts a
limitation on the depth of the tree of about 40 or 50 levels, which I think
may be enough for most users. To increase the maximum depth of the tree,
increase the size of the string that is being used or change it to a text to
remove the limitation entirely. Changing it to a text will however decrease
performance because an index cannot be put on the column in that case.

The materialised path pattern requires Ancestry to use a 'like' condition in
order to fetch descendants. This should not be particularly slow however since
the the condition never starts with a wildcard which allows the DBMS to use
the column index. If you have any data on performance with a large number of
records, please drop me line.

# Contributing and license

I will try to keep Ancestry up to date with changing versions of Rails and
Ruby and also with any bug reports I might receive. I will implement new
features on request as I see fit and have time.

Question? Bug report? Faulty/incomplete documentation? Feature request? Please
post an issue on 'http://github.com/stefankroes/ancestry/issues'. Make sure
you have read the documentation and you have included tests and documentation
with any pull request.

Copyright (c) 2016 Stefan Kroes, released under the MIT license