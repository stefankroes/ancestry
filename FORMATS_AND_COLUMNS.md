# Ancestry Formats and Column Configuration

This document covers ancestry column formats in depth, database-specific column setup,
collation requirements, and migrating between formats.

For basic installation, see the [README](README.md).

## Ancestry Formats

Ancestry supports several storage formats for the ancestry column. Each format
determines the column type, how paths are stored, and what SQL operators are used
for tree queries.

### Format Summary

| Format | Column | Root value | Path example | Descendant SQL | Database |
|--------|--------|-----------|--------------|----------------|----------|
| `:materialized_path` | `string` | `nil` | `1/2/3` | `LIKE '1/2/3/%' OR = '1/2/3'` | Any |
| `:materialized_path2` | `string` | `/` | `/1/2/3/` | `LIKE '/1/2/3/%'` | Any |
| `:materialized_path3` | `string` | `""` | `1/2/3/` | `LIKE '1/2/3/%'` | Any |
| `:ltree` | `ltree` | `""` | `1.2.3` | `<@ '1.2.3'` | PostgreSQL |

### Choosing a Format

**`:materialized_path2`** is recommended for most applications:

- `NOT NULL` column — no nil handling
- Trailing delimiter eliminates the `OR` in descendant queries (faster)
- Path can be constructed in SQL (useful for generated columns)

**`:materialized_path`** is the legacy default. It uses `nil` for root nodes, which
requires `NULL` columns and an extra `OR` condition in descendant queries. Kept for
backward compatibility.

**`:materialized_path3`** is like mp2 but uses `""` (empty string) for root nodes
instead of `"/"`. Slightly simpler root handling.

**`:ltree`** uses PostgreSQL's native [ltree](https://www.postgresql.org/docs/current/ltree.html)
type with GiST indexing. Descendant queries use the `<@` operator instead of `LIKE`,
and depth/path extraction use native functions (`nlevel()`, `subpath()`). Requires the
`ltree` extension and PostgreSQL.

### Format Details

#### `:materialized_path` (legacy default)

```
Root node:   ancestry = nil
Child of 1:  ancestry = "1"
Grandchild:  ancestry = "1/2"
```

- Column must allow `NULL`
- Descendant query: `ancestry LIKE '1/2/%' OR ancestry = '1/2'`
- The `OR` is needed because direct children have ancestry `"1/2"` (no trailing `/`)

#### `:materialized_path2` (recommended)

```
Root node:   ancestry = "/"
Child of 1:  ancestry = "/1/"
Grandchild:  ancestry = "/1/2/"
```

- Column is `NOT NULL`
- Descendant query: `ancestry LIKE '/1/2/%'`
- Trailing delimiter means direct children (`/1/2/3/`) match the `LIKE` pattern — no `OR` needed

#### `:materialized_path3`

```
Root node:   ancestry = ""
Child of 1:  ancestry = "1/"
Grandchild:  ancestry = "1/2/"
```

- Column is `NOT NULL`
- Descendant query: `ancestry LIKE '1/2/%'`
- Like mp2 but root is empty string instead of `"/"`

#### `:ltree` (PostgreSQL only)

```
Root node:   ancestry = ""
Child of 1:  ancestry = "1"
Grandchild:  ancestry = "1.2"
```

- Requires `enable_extension 'ltree'`
- Column is `NOT NULL`, type is `ltree`
- Descendant query: `ancestry <@ '1.2'` (GiST-indexed)
- `nlevel(ancestry)` for depth, `subpath()` for path extraction
- Integer primary keys only (ltree labels must be alphanumeric)

## Collation and Indexes

### Why Collation Matters

The string-based ancestry formats (mp1, mp2, mp3) use `LIKE 'prefix%'` for descendant
queries. For the database to use a btree index on `LIKE`, it must know the column uses
simple byte ordering — not locale-aware Unicode collation.

The problem: standard Unicode collation (as of 2018) **ignores punctuation for sorting**.
This means the `/` delimiter in ancestry paths is ignored, causing:

1. **Wrong query results** — `LIKE` may match incorrect rows
2. **Index not used** — the query planner falls back to sequential scan

Since ancestry only uses ASCII characters (`0-9`, `/`, `.`), telling the database to use
binary/ascii collation fixes both issues.

### What `t.ancestry` Does Automatically

The `t.ancestry` migration helper detects your database and sets the correct collation:

| Database | Collation | Why |
|----------|-----------|-----|
| PostgreSQL | `'C'` | POSIX byte ordering, fastest for ASCII |
| MySQL | `'utf8mb4_bin'` | Binary comparison within utf8mb4 charset |
| SQLite | _(none)_ | SQLite uses binary comparison by default |

It also creates the appropriate index:

| Format | Index type |
|--------|-----------|
| String formats | btree (default) |
| `:ltree` | GiST |

### Disabling Automatic Collation

If you need a specific collation (or none), pass `collation: false` or a string:

```ruby
t.ancestry collation: false                # no collation set
t.ancestry collation: 'en_US.utf8'         # specific collation
```

## Manual Column Setup

If you cannot use `t.ancestry` (e.g., adding ancestry to an existing table via
`ALTER TABLE`), set up the column manually.

### PostgreSQL

**Option A: C collation (recommended)**

```ruby
t.string "ancestry", collation: 'C', null: false
t.index "ancestry"
```

The `'C'` collation uses POSIX byte ordering. This is the simplest and fastest option.

**Option B: ascii index with standard collation**

If you need to keep a locale-aware collation on the column (e.g., for application-level
sorting), use an operator class on the index instead:

```ruby
t.string "ancestry", null: false
t.index  "ancestry", opclass: :varchar_pattern_ops
```

The `varchar_pattern_ops` operator class tells PostgreSQL to use byte-wise comparison
for this index only, without changing the column's collation.

**Option C: binary column**

```ruby
t.binary "ancestry", limit: 3000, null: false
t.index  "ancestry"
```

Binary columns bypass locale entirely, but SQL output is less readable and the `:sql`
update strategy is not supported. You may improve readability with:

```sql
ALTER DATABASE dbname SET bytea_output TO 'escape';
```

### MySQL

**Option A: utf8mb4_bin collation (recommended)**

```ruby
t.string "ancestry", collation: 'utf8mb4_bin', null: false
t.index "ancestry"
```

**Option B: binary collation**

```ruby
t.string "ancestry", collation: 'binary', limit: 3000, null: false
t.index  "ancestry"
```

**Option C: binary column**

```ruby
t.binary "ancestry", limit: 3000, null: false
t.index  "ancestry"
```

**Option D: ascii character set (SQL only)**

```sql
ALTER TABLE table_name
  ADD COLUMN ancestry VARCHAR(2700) CHARACTER SET ascii;
```

MySQL supports per-column character sets. The `ascii` charset is single-byte and
sorts correctly for ancestry paths.

### SQLite

```ruby
t.string "ancestry", null: false
t.index "ancestry"
```

SQLite uses binary comparison by default — no collation configuration needed.

### Ltree (PostgreSQL)

```ruby
enable_extension 'ltree'
t.column "ancestry", :ltree, null: false, default: ''
t.index "ancestry", using: :gist
```

Or simply use `t.ancestry format: :ltree`, which does all of this.

## Migrating Collation

If you are adding collation to an existing ancestry column, you must drop and recreate
the index. Changing the collation of a column invalidates any existing btree index on it.

```ruby
class FixAncestryCollation < ActiveRecord::Migration[7.0]
  def change
    remove_index :table, :ancestry
    change_column :table, :ancestry, :string, collation: 'C', null: false
    add_index :table, :ancestry
  end
end
```

## Migrating Between Formats

### From `:materialized_path` to `:materialized_path2`

```ruby
klass = YourModel
# Wrap existing paths with delimiters: "1/2/3" → "/1/2/3/"
klass.where.not(ancestry: nil).update_all("ancestry = CONCAT('/', ancestry, '/')")
# Convert root nodes: nil → "/"
klass.where(ancestry: nil).update_all("ancestry = '/'")
# Disallow nulls now that all roots have a value
change_column_null klass.table_name, :ancestry, false
```

Then update your model:

```ruby
has_ancestry ancestry_format: :materialized_path2
```

### From `:materialized_path` to `:materialized_path3`

```ruby
klass = YourModel
# Append delimiter: "1/2/3" → "1/2/3/"
klass.where.not(ancestry: nil).update_all("ancestry = CONCAT(ancestry, '/')")
# Convert root nodes: nil → ""
klass.where(ancestry: nil).update_all("ancestry = ''")
change_column_null klass.table_name, :ancestry, false
```

### From `:materialized_path2` to `:materialized_path3`

```ruby
klass = YourModel
# Strip leading delimiter: "/1/2/3/" → "1/2/3/"
klass.where.not(ancestry: '/').update_all("ancestry = SUBSTRING(ancestry, 2)")
# Convert root nodes: "/" → ""
klass.where(ancestry: '/').update_all("ancestry = ''")
```

## Column Size Limits

Btree indexes have a maximum key size (typically 2704 bytes on PostgreSQL). For a
`string` ancestry column, this limits the maximum tree depth:

| ID length | Max path length | Approximate max depth |
|-----------|----------------|----------------------|
| 1-2 digits | ~2700 chars | ~900 |
| 4 digits | ~2700 chars | ~540 |
| 6 digits | ~2700 chars | ~385 |
| UUID (36 chars) | ~2700 chars | ~73 |

The `:ltree` and `:array` formats have their own limits but are generally comparable.

For most applications, these limits are not a concern. If you need very deep trees
(hundreds of levels), consider whether your data model truly requires that depth.
