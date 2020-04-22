Gem::Specification.new do |s|
  s.name     = 'the_schema_is'
  s.version  = '0.0.1'
  s.authors  = ['Victor Shepelev']
  s.email    = 'zverok.offline@gmail.com'
  s.homepage = 'https://github.com/zverok/the_schema_is'

  s.summary = 'ActiveRecord model annotations done right'
  s.description = <<-EOF
    Annotating ActiveRecord models with lists of columns defined through DSL and checked with
    custom Rubocop's cop.
  EOF
  s.licenses = ['MIT']

  s.required_ruby_version = '>= 2.6.0'

  s.files = `git ls-files lib config LICENSE.txt *.md`.split($RS)
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'backports', '>= 3.16.0'
  s.add_runtime_dependency 'rubocop'
  s.add_runtime_dependency 'activesupport' # it is a plugin for ActiveRecord anyways, and we need perfectly same inflection
  s.add_runtime_dependency 'ffast', '>= 0.1.8'
  s.add_runtime_dependency 'memoist'

  s.add_development_dependency 'rubocop-rspec'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'rubygems-tasks'
end
