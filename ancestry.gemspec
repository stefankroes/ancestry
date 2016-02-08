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

  s.version = Ancestry::VERSION

  s.author   = 'Stefan Kroes'
  s.email    = 's.a.kroes@gmail.com'
  s.homepage = 'http://github.com/stefankroes/ancestry'
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
    'MIT-LICENSE',
    'README.rdoc'
  ]
  
  s.required_ruby_version     = '>= 1.8.7'
  s.add_runtime_dependency 'activerecord', '>= 3.0.0'
  s.add_development_dependency 'rake',      '~> 10.0'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'mysql'
end
