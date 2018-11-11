lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)
require 'ancestry/version'

Gem::Specification.new do |s|
  s.name        = 'ancestry'
  s.summary     = 'Organize ActiveRecord model into a tree structure'
  s.description = <<-EOF
  Ancestry allows the records of a ActiveRecord model to be organized in a tree
  structure, using a single, intuitively formatted database column. It exposes
  all the standard tree structure relations (ancestors, parent, root, children,
  siblings, descendants) and all of them can be fetched in a single sql query.
  Additional features are named_scopes, integrity checking, integrity restoration,
  arrangement of (sub)tree into hashes and different strategies for dealing with
  orphaned records.
EOF
  s.metadata = {
    "homepage_uri" => "https://github.com/stefankroes/ancestry",
    "changelog_uri" => "https://github.com/stefankroes/ancestry/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/stefankroes/ancestry/",
    "bug_tracker_uri" => "https://github.com/stefankroes/ancestry/issues",
  }
  s.version = Ancestry::VERSION

  s.authors  = ['Stefan Kroes', 'Keenan Brock']
  s.email    = 'keenan@thebrocks.net'
  s.homepage = 'https://github.com/stefankroes/ancestry'
  s.license  = 'MIT'

  s.files = [
    'ancestry.gemspec',
    'init.rb',
    'install.rb',
    'lib/ancestry.rb',
    'lib/ancestry/has_ancestry.rb',
    'lib/ancestry/exceptions.rb',
    'lib/ancestry/class_methods.rb',
    'lib/ancestry/instance_methods.rb',
    'lib/ancestry/materialized_path.rb',
    'lib/ancestry/version.rb',
    'MIT-LICENSE',
    'README.md'
  ]
  
  s.required_ruby_version     = '>= 1.8.7'
  s.add_runtime_dependency 'activerecord', '>= 3.2.0'
  s.add_development_dependency 'rdoc'
  s.add_development_dependency 'yard'
  s.add_development_dependency 'rake',      '~> 10.0'
  s.add_development_dependency 'test-unit'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'sqlite3'
end
