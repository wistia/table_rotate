Gem::Specification.new do |s|
  s.name        = 'table_rotate'
  s.version     = '0.0.1'
  s.date        = '2016-02-08'
  s.summary     = 'Rotate your mysql records and still query easily with ActiveRecord.'
  s.description = 'It would be really nice if data in mysql could be deleted with no penalty. TableRotate provides a mechanism to archive tables atomically, with no overhead, and to easily query those archived tables in ActiveRecord. There are a few tradeoffs, but it can make sense for some data streams.'
  s.authors     = ['Max Schnur, Wistia']
  s.email       = 'max@wistia.com'
  s.files       = ['lib/table_rotate.rb']
  s.homepage    = 'http://rubygems.org/gems/table_rotate'
  s.license      = 'MIT'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'activerecord'
  s.add_development_dependency 'mysql'
end
