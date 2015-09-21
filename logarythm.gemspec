$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "logarythm/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "logarythm"
  s.version     = Logarythm::VERSION
  s.authors     = ["Yassine Zenati"]
  s.email       = ["yassine@capsens.eu"]
  s.homepage    = ""
  s.summary     = "Summary of Logarythm."
  s.description = "Description of Logarythm."
  s.license     = "MIT"

  s.files = Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "rails", "~> 4.2.3"
  s.add_runtime_dependency 'redis'

  s.add_development_dependency "sqlite3"
end
