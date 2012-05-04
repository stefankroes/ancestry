Gem::Specification.new do |s|
  s.name        = 'ancestry'
  s.description = 'Organise ActiveRecord model into a tree structure'
  s.summary     = 'Ancestry allows the records of a ActiveRecord model to be organised in a tree structure, using a single, intuitively formatted database column. It exposes all the standard tree structure relations (ancestors, parent, root, children, siblings, descendants) and all of them can be fetched in a single sql query. Additional features are named_scopes, integrity checking, integrity restoration, arrangement of (sub)tree into hashes and different strategies for dealing with orphaned records.'

  s.version = '1.2.5'

  s.author   = 'Stefan Kroes'
  s.email    = 's.a.kroes@gmail.com'
  s.homepage = 'http://github.com/stefankroes/ancestry'

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
  
  s.add_dependency 'activerecord', '>= 2.2.2'
end
