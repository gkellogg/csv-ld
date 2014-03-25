#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.version               = File.read('VERSION').chomp
  gem.date                  = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.name                  = "csv-ld"
  gem.homepage              = "http://github.com/ruby-rdf/csv-ld"
  gem.license               = 'Public Domain' if gem.respond_to?(:license=)
  gem.summary               = "CSV-LD processor for Ruby"
  gem.description           = "CSV::LD transforms CSV to JSON-LD and RDF."
  gem.rubyforge_project     = 'csv-ld'

  gem.authors               = ['Gregg Kellogg']
  gem.email                 = 'public-csvw-wg@w3.org'

  gem.platform              = Gem::Platform::RUBY
  gem.files                 = %w(AUTHORS README.md LICENSE VERSION) + Dir.glob('lib/**/*.rb')
  gem.bindir               = %q(bin)
  gem.executables          = %w(csvld)
  gem.default_executable   = gem.executables.first
  gem.require_paths         = %w(lib)
  gem.extensions            = %w()
  gem.test_files            = Dir.glob('spec/**/*.rb') + Dir.glob('spec/test-files/*')
  gem.has_rdoc              = false

  gem.required_ruby_version = '>= 1.9.2'
  gem.requirements          = []
  gem.add_runtime_dependency     'rdf',             '~> 1.1', '>= 1.1.2.1'
  gem.add_runtime_dependency     'json-ld',         '~> 1.1'
  gem.add_development_dependency 'yard' ,           '>= 0.8.7'
  gem.add_development_dependency 'rspec',           '~> 2.14'
  gem.add_development_dependency 'rdf-turtle',      '>= 1.0.7'
  gem.add_development_dependency 'rdf-isomorphic',  '~> 1.1'
  gem.add_development_dependency 'rdf-xsd',         '~> 1.1'

  gem.post_install_message  = nil
end
