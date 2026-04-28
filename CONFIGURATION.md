# Configuration Reference

Full reference for `has_ancestry` options, global defaults, and advanced setup.

For getting started, see the [README](README.md).
For upgrading between versions, see [Upgrading](docs/UPGRADING.md).

> **Reading these docs on GitHub?** The `master` branch reflects bleeding-edge
> development and may describe features not yet released. Use the branch
> selector above to switch to the [tag](https://github.com/stefankroes/ancestry/tags)
> matching the version of the gem you have installed.

## Table of Contents

- [Ancestry Formats](#ancestry-formats)
- [Cached Columns](#cached-columns)
- [Depth Constraints](#depth-constraints)
- [Counter Cache](#counter-cache)
- [Touch Ancestors](#touch-ancestors)
- [Update Strategy](#update-strategy)
- [UUID Primary Keys](#uuid-primary-keys)
- [Collation and Manual Column Setup](#collation-and-manual-column-setup)
- [Column Size Limits](#column-size-limits)
- [Migrating from parent_id](#migrating-from-plugin-that-uses-parent_id-column)

For global defaults and the full has_ancestry options table, see the [README](README.md#has_ancestry-options).

## Ancestry Formats

| Format                  | Root    | Example      | Descendant SQL                 | NOT NULL | Database   | Status                  |
|-------------------------|---------|--------------|--------------------------------|----------|------------|-------------------------|
| `:materialized_path`    | `nil`   | `1/2/3`      | `LIKE '../%' OR = '..'`       | no       | Any        | Default (legacy)        |
| `:materialized_path2`   | `/`     | `/1/2/3/`    | `LIKE '../%'`                  | yes      | Any        | Superseded by mp3       |
| `:materialized_path3`   | `""`    | `1/2/3/`     | `LIKE '../%'`                  | yes      | Any        | **Recommended**         |
| `:ltree`                | `""`    | `1.2.3`      | `<@ '1.2.3'`                  | yes      | PostgreSQL | **Recommended (PG)**    |

**mp1** is the original format (v1.0) used by ~90% of installations. Descendant
queries require an `OR` because children (`ancestry = '1'`) don't match
`LIKE '1/%'`. Root is `NULL`, so the column can't be `NOT NULL`.

**mp2** (v4.3) fixed the `OR` by adding a trailing delimiter. Also enabled
`NOT NULL` columns. Root is `"/"`.

**mp3** has the same performance as mp2 but root is `""` (empty string) instead
of `"/"` — slightly simpler root handling in SQL and Ruby. This is the
recommended format for new projects. If migrating from mp1, mp3 is the target.

**ltree** uses PostgreSQL's native [ltree](https://www.postgresql.org/docs/current/ltree.html)
type with GiST indexing. Descendants use the `<@` operator — no `LIKE`, no
collation concerns. Depth via `nlevel()`, path extraction via `subpath()`.
Integer primary keys only (not compatible with UUIDs).

### Migrating Between Formats

#### From `:materialized_path` to `:materialized_path3`

```ruby
klass = YourModel
# Append delimiter: "1/2/3" → "1/2/3/"
klass.where.not(ancestry: nil).update_all("ancestry = CONCAT(ancestry, '/')")
# Convert root nodes: nil → ""
klass.where(ancestry: nil).update_all("ancestry = ''")
change_column_null klass.table_name, :ancestry, false
```

#### From `:materialized_path` to `:materialized_path2`

```ruby
klass = YourModel
# Wrap existing paths with delimiters: "1/2/3" → "/1/2/3/"
klass.where.not(ancestry: nil).update_all("ancestry = CONCAT('/', ancestry, '/')")
# Convert root nodes: nil → "/"
klass.where(ancestry: nil).update_all("ancestry = '/'")
change_column_null klass.table_name, :ancestry, false
```

#### From `:materialized_path2` to `:materialized_path3`

```ruby
klass = YourModel
# Strip leading delimiter: "/1/2/3/" → "1/2/3/"
klass.where.not(ancestry: '/').update_all("ancestry = SUBSTRING(ancestry, 2)")
# Convert root nodes: "/" → ""
klass.where(ancestry: '/').update_all("ancestry = ''")
```

## Cached Columns

Ancestry derives `parent_id`, `root_id`, and `depth` by parsing the ancestry
column. These options store those values in real database columns for queries,
joins, and indexing.

Each of the options below also accepts `:virtual` to use a database generated
column instead of callbacks. Generated columns are defined in your migration
and computed automatically by the database from the ancestry column — no
rebuild step is needed. See your database's docs for details:
[MySQL](https://dev.mysql.com/doc/refman/8.0/en/create-table-generated-columns.html),
[PostgreSQL](https://www.postgresql.org/docs/current/ddl-generated-columns.html).

### Depth Cache

```ruby
has_ancestry cache_depth: true               # callback-maintained, column: ancestry_depth
has_ancestry cache_depth: :virtual           # database-generated column (recommended)
has_ancestry cache_depth: :my_depth_column   # custom column name
```

Depth caching enables the [depth scopes](#depth-constraints) and depth-based
filtering. With `:virtual`, the database computes the value — no callbacks,
no rebuild step.

### Parent Cache and Associations

```ruby
has_ancestry parent: :virtual    # recommended — database-generated parent_id
has_ancestry parent: true        # callback-maintained parent_id
```

When `parent:` is set, ancestry defines real ActiveRecord associations:
- `belongs_to :parent` — enables `includes(:parent)`, `joins(:parent)`
- `has_many :children` — enables `includes(:children)`, `joins(:children)`

These support eager loading, preloading, and inverse caching:

```ruby
class TreeNode < ActiveRecord::Base
  has_ancestry parent: true
end

# Eager load parents to avoid N+1
TreeNode.where(depth: 2).includes(:parent)

# Eager load children
roots = TreeNode.roots.includes(:children)
roots.each { |r| r.children } # no extra queries

# Join queries
TreeNode.joins(:parent).where(parents_tree_nodes: { name: "Root" })
```

Virtual columns require Rails 7.2+ for SQLite, Rails 7.0+ for PostgreSQL
and MySQL.

### Root Cache

```ruby
has_ancestry root: :virtual     # database-generated root_id (PostgreSQL, SQLite)
has_ancestry root: true         # callback-maintained root_id
```

When `root:` is set, ancestry defines:
- `belongs_to :root` — enables `includes(:root)`, `joins(:root)`

**Limitations:**
- `root: :virtual` is not supported on MySQL. MySQL generated columns cannot
  reference auto-increment columns, and `root_id` equals `id` for root nodes.
  Use `root: true` (callback-maintained) on MySQL instead.
- `root: true` requires an extra UPDATE after creating root nodes, since the
  `root_id` of a root node is its own `id` (not available until after INSERT).

### Rebuild Cache Columns

After bulk imports or direct SQL changes that bypass callbacks:

```ruby
Model.rebuild_depth_cache!          # depth cache
Model.rebuild_parent_id_cache!      # parent_id cache
Model.rebuild_root_id_cache!        # root_id cache
Model.rebuild_counter_cache!        # counter cache

# SQL alternatives (faster, single query):
Model.rebuild_depth_cache_sql!
Model.rebuild_parent_id_cache_sql!
Model.rebuild_root_id_cache_sql!
```

## Depth Constraints

With depth caching enabled, you can constrain tree depth using standard Rails
validations:

```ruby
has_ancestry cache_depth: true
validates :ancestry_depth, numericality: { less_than_or_equal_to: 5 }
```

Ancestry validates not just the node itself, but also ensures that moving a
subtree does not cause any descendant to exceed the maximum depth.

### Depth Scopes

```ruby
Model.at_depth(2)         # depth == 2
Model.before_depth(3)     # depth < 3
Model.to_depth(3)         # depth <= 3
Model.from_depth(2)       # depth >= 2
Model.after_depth(2)      # depth > 2
```

Depth scopes work without `cache_depth` (computed via SQL), but for production
use, enable `cache_depth` to avoid per-row SQL calculations.

Depth options on navigation methods use relative depth:

```ruby
node.descendants(:from_depth => 2, :to_depth => 4)
node.ancestors(:from_depth => -6, :to_depth => -4)
node.path.from_depth(3).to_depth(4)
node.subtree.from_depth(10).to_depth(12)
```

Note: depth constraints cannot be passed to `ancestor_ids` or `path_ids` as both
can be fetched directly from the ancestry column without a query. Use
`ancestors(depth_options).map(&:id)` or `ancestor_ids.slice(min..max)` instead.

## Counter Cache

Cache the number of children:

```ruby
has_ancestry counter_cache: true                # column: children_count
has_ancestry counter_cache: :num_children       # custom column name
```

The counter is maintained via callbacks on create, destroy, and reparent.
Rebuild after bulk changes:

```ruby
Model.rebuild_counter_cache!
```

## Touch Ancestors

Touch all ancestors when a node changes (useful for cache invalidation):

```ruby
has_ancestry touch: true
```

This fires `after_touch`, `after_destroy`, and `after_save` callbacks that
touch each ancestor record.

## Update Strategy

Controls how descendant records are updated when a node is reparented:

```ruby
has_ancestry update_strategy: :ruby    # default — loads each descendant, fires callbacks
has_ancestry update_strategy: :sql     # single SQL statement, no callbacks on descendants
```

`:sql` works on all databases (SQLite, MySQL, PostgreSQL) as of version 5.1.
Use it for large trees where reparenting performance matters. Depth cache and
root cache columns are updated correctly even with `:sql`.

## Primary Key Format

```ruby
has_ancestry primary_key_format: :integer   # default
has_ancestry primary_key_format: :uuid      # UUIDs
has_ancestry primary_key_format: :string    # alphanumeric string ids
```

Custom regex is also supported for non-standard formats:

```ruby
has_ancestry primary_key_format: '[a-z0-9]{8}'
```

## UUID Primary Keys

Use `primary_key_format: :uuid` with any string-based format (mp1, mp2, mp3):

```ruby
has_ancestry primary_key_format: :uuid
```

The ancestry column is always a `string` — it stores paths like `"uuid1/uuid2/uuid3"`.
Do not use a `uuid` typed column for ancestry.

Note: `:ltree` and `:array` formats are not compatible with UUID primary keys.

## Collation and Manual Column Setup

The `t.ancestry` migration helper handles column type, collation, and indexes
automatically. If you cannot use `t.ancestry`, set up the column manually.

String-based formats need collation set correctly to use indexes for `LIKE` queries.
Non-string formats (`:ltree`, `:array`) handle indexing natively.

### PostgreSQL

```ruby
# C collation ensures LIKE uses the btree index
t.string "ancestry", collation: 'C', null: false
t.index "ancestry"
```

### MySQL

```ruby
t.string "ancestry", collation: 'utf8mb4_bin', null: false
t.index "ancestry"
```

### SQLite

```ruby
# SQLite uses binary comparison by default — no collation needed
t.string "ancestry", null: false
t.index "ancestry"
```

### Ltree (PostgreSQL)

```ruby
enable_extension 'ltree'
t.column "ancestry", :ltree, null: false, default: ''
t.index "ancestry", using: :gist
```

### Migrating Collation

If adding collation to an existing ancestry column, drop and recreate the index:

```ruby
class FixAncestryCollation < ActiveRecord::Migration[7.0]
  def change
    remove_index :table, :ancestry
    change_column :table, :ancestry, :string, collation: 'C', null: false
    add_index :table, :ancestry
  end
end
```

## Column Size Limits

Btree indexes have a maximum key size (typically 2704 bytes on PostgreSQL).

| ID length        | Approximate max depth |
|------------------|-----------------------|
| 1-2 digits       | ~900                  |
| 4 digits         | ~540                  |
| 6 digits         | ~385                  |
| UUID (36 chars)  | ~73                   |

For most applications, these limits are not a concern.

## Migrating from plugin that uses parent_id column

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

