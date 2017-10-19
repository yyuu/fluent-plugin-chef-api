# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "fluent-plugin-chef-api"
  spec.version       = "0.5.1"
  spec.authors       = ["Yamashita Yuu"]
  spec.email         = ["peek824545201@gmail.com"]
  spec.license       = "Apache-2.0"

  spec.summary       = %q{A fluentd plugin for Chef's API}
  spec.description   = %q{A fluentd plugin for Chef's API.}
  spec.homepage      = "https://github.com/yyuu/fluent-plugin-chef-api"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.9"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_dependency "fluentd"
  spec.add_dependency "chef-api", "~> 0.5.0"
end
