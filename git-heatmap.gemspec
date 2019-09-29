require_relative "lib/git/heatmap/version"

Gem::Specification.new do |spec|
	spec.name          = "git-heatmap"
	spec.version       = Git::Heatmap::VERSION
	spec.authors       = ["Samuel Williams"]
	spec.email         = ["samuel.williams@oriontransfer.co.nz"]
	
	spec.summary       = "Generate heatmap style visualisations based on git history."
	spec.homepage      = "https://github.com/ioquatix/git-heatmap"
	
	# Specify which files should be added to the gem when it is released.
	# The `git ls-files -z` loads the files in the RubyGem that have been added into git.
	spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
		`git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
	end
	
	spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
	spec.require_paths = ["lib"]
	
	spec.add_dependency "console"
	spec.add_dependency "rugged"
	spec.add_dependency "trenni"
	spec.add_dependency "samovar", "~> 2.0"
	
	spec.add_development_dependency "bundler"
	spec.add_development_dependency "rake", "~> 10.0"
	spec.add_development_dependency "rspec", "~> 3.0"
end
