# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$:.unshift(lib) unless $:.include?(lib)
require 'cult/version'

Gem::Specification.new do |spec|
  spec.name          = "cult"
  spec.version       = Cult::VERSION
  spec.authors       = ["Mike Owens"]
  spec.email         = ["mike@mikeowens.us"]

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
                                                     .reject { |f| f.match(%r{^doc/images/})}
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = '>= 2.5.3'

  spec.add_dependency "cri", "~> 2.15"

  spec.add_dependency "net-ssh", "~> 4.2"
  spec.add_dependency "net-scp", "~> 1.2"
  spec.add_dependency "rbnacl", ">= 3.2", "< 5.0"

  spec.add_dependency "rainbow", "~> 3.0"
  spec.add_dependency "erubi", "~> 1.7"
  spec.add_dependency "terminal-table", "~> 1.8"

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.3"
end
