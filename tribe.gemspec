# -*- encoding: utf-8 -*-
require File.expand_path('../lib/tribe/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Chad Remesch"]
  gem.email         = ["chad@remesch.com"]
  gem.description   = %q{Actor Model for Ruby}
  gem.summary       = %q{Actor Model for Ruby designed for high performance and millions of event driven actors.}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($\)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.name          = "tribe"
  gem.require_paths = ["lib"]
  gem.version       = Tribe::VERSION
end
