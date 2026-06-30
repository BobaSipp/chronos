Gem::Specification.new do |s|
  s.name        = "chronos"
  s.version     = "0.1b"
  s.summary     = "Lightweight terminal-based Git repository analytics dashboard"
  s.description = "A Ruby TUI that gives you a live, interactive overview of your Git repository's commit activity. Zero external dependencies."

  s.authors     = ["BobaSipp"]
  s.email       = ""
  s.homepage    = "https://github.com/BobaSipp/chronos"
  s.license     = "MIT"

  s.files       = Dir["lib/**/*.rb"] + ["LICENSE", "README.md"]
  s.bindir      = "bin"
  s.executables = ["chronos"]

  s.required_ruby_version = ">= 2.7"
  s.metadata["source_code_uri"] = "https://github.com/BobaSipp/chronos"
end
