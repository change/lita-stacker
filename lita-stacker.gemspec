# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name          = 'lita-stacker'
  spec.version       = '0.1.0'
  spec.authors       = ['Kyle VanderBeek']
  spec.email         = ['kyle@change.org']
  spec.summary       = 'A Lita handler for keeping order of people who wish to speak.'
  spec.description   = 'Keeps a queue of people who have "stacked" on the current point of order.'
  spec.homepage      = 'http://github.com/change/lita-stacker'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'lita', '~> 4.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.7.0'
  spec.add_development_dependency 'rubocop', '>= 0.58.1'
end
