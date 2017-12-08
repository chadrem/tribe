# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'tribe/version'

Gem::Specification.new do |spec|
  spec.name          = "tribe"
  spec.version       = Tribe::VERSION
  spec.authors       = ["Chad Remesch"]
  spec.email         = ["chad@remesch.com"]

  spec.summary       = %q{Actors based concurrency library for Ruby.}
  spec.homepage      = "https://github.com/chadrem/tribe"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "workers", "~> 0.6.1"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "minitest"
end
