# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'lita-stacker'

Gem::Specification.new do |spec|
  spec.name          = 'lita-stacker'
  spec.version       = Lita::Handlers::Stacker::VERSION
  spec.authors       = ['Kyle VanderBeek']
  spec.email         = ['kyle@change.org']
  spec.summary       = 'A Lita handler for keeping order of people who wish to speak.'
  spec.description   = 'Keeps a queue of people who have "stacked" on the current point of order.'
  spec.homepage      = 'http://github.com/change/lita-stacker'
  spec.license       = 'MIT'
  spec.metadata      = { 'lita_plugin_type' => 'handler' }

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR).reject { |f| f =~ %r{^i/} }
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '~> 5.2'
  spec.add_runtime_dependency 'lita', '~> 4.0'

  spec.add_development_dependency 'bundler', '~> 1.16'
  spec.add_development_dependency 'byebug'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.7.0'
  spec.add_development_dependency 'rubocop', '>= 0.58.1'
  spec.add_development_dependency 'rubocop-rspec', '>= 1.28.0'
end
