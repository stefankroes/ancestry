# frozen_string_literal: true

lib = File.expand_path('../lib/', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ancestry/version'

Gem::Specification.new do |s|
  s.name        = 'ancestry'
  s.summary     = 'Organize ActiveRecord model into a tree structure'
  s.description = <<-EOF
  Ancestry allows the records of a ActiveRecord model to be organized in a tree
  structure, using the materialized path pattern. It exposes the standard
  relations (ancestors, parent, root, children, siblings, descendants)
  and allows them to be fetched in a single query. Additional features include
  named scopes, integrity checking, integrity restoration, arrangement
  of (sub)tree into hashes and different strategies for dealing with orphaned
  records.
EOF

  s.post_install_message = "Thank you for installing Ancestry. You can visit http://github.com/stefankroes/ancestry to read the documentation."

  s.metadata = {
    "homepage_uri" => "https://github.com/stefankroes/ancestry",
    "changelog_uri" => "https://github.com/stefankroes/ancestry/blob/master/CHANGELOG.md",
    "source_code_uri" => "https://github.com/stefankroes/ancestry/",
    "bug_tracker_uri" => "https://github.com/stefankroes/ancestry/issues",
    "rubygems_mfa_required" => "true"
  }
  s.version = Ancestry::VERSION

  s.authors  = ['Stefan Kroes', 'Keenan Brock']
  s.email    = 'keenan@thebrocks.net'
  s.homepage = 'https://github.com/stefankroes/ancestry'
  s.license  = 'MIT'

  s.files = Dir[
    "{lib}/**/*",
    'CHANGELOG.md',
    'MIT-LICENSE',
    'README.md'
  ]
  s.require_paths = ["lib"]

  s.required_ruby_version = '>= 2.5'
  s.add_runtime_dependency 'activerecord', '>= 5.2.6'
  s.add_runtime_dependency 'logger'
  
  s.add_development_dependency 'appraisal'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'rake', '~> 13.0'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'yard'
end
