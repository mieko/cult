# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'cult/version'

Gem::Specification.new do |spec|
  spec.name          = "cult"
  spec.version       = Cult::VERSION
  spec.authors       = ["Mike Owens"]
  spec.email         = ["mike@meter.md"]

  spec.summary       = "Fleet Management like its 1990"
  spec.homepage      = "https://github.com/mieko/cult"
  spec.license       = "MIT"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "https://rubygems.org"
  else
    raise "RubyGems 2.0 or newer is required to protect against public gem pushes."
  end

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '~> 2.3'

  spec.add_dependency "listpager", "~> 1.0.4"
  spec.add_dependency "net-ssh",   "~> 3.2.0"
  spec.add_dependency "colorize",  "~> 0.8.1"
  spec.add_dependency "rouge",     "~> 2.0.5"

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
end
