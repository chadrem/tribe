# -*- encoding: utf-8 -*-
require File.expand_path('../lib/tribe/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Chad Remesch"]
  gem.email         = ["chad@remesch.com"]
  gem.description   = %q{Tribe is a Ruby gem that implements event-driven actors.}
  gem.summary       = %q{Actors are lightweight concurrent objects that use asynchronous message passing for communication. Tribe focuses on high performance, low latency, an easy to use API, and flexibility.}
  gem.homepage      = "https://github.com/chadrem/tribe"

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "tribe"
  gem.require_paths = ["lib"]
  gem.version       = Tribe::VERSION

  gem.add_dependency('workers', '0.1.4')
end
