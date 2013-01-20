# -*- encoding: utf-8 -*-
require File.expand_path('../lib/tribe/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Chad Remesch"]
  gem.email         = ["chad@remesch.com"]
  gem.description   = %q{Event driven actors for Ruby}
  gem.summary       = %q{Event driven actors for Ruby designed for high performance.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "tribe"
  gem.require_paths = ["lib"]
  gem.version       = Tribe::VERSION

  gem.add_dependency('workers', ['0.0.6'])
end
