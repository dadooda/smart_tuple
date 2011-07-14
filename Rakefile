require "rake/rdoctask"
require "yaml"

GEM_NAME = "smart_tuple"

begin
  require "jeweler"
  Jeweler::Tasks.new do |gem|
    gem.name = GEM_NAME
    gem.summary = "A Simple Yet Smart SQL Conditions Builder"
    gem.description = "A Simple Yet Smart SQL Conditions Builder"
    gem.email = "alex.r@askit.org"
    gem.homepage = "http://github.com/dadooda/smart_tuple"
    gem.authors = ["Alex Fortuna"]
    gem.files = FileList[
      "[A-Z]*",
      "*.gemspec",
      "init.rb",
      "lib/**/*.rb",
      "spec/**/*.rb",
    ]
  end
rescue LoadError
  STDERR.puts "This gem requires Jeweler to be built"
end

desc "Rebuild gemspec and package"
task :rebuild => [:gemspec, :build]

desc "Push (publish) gem to RubyGems.org"
task :push do
  # NOTE: Yet found no way to ask Jeweler forge a complete version string for us.
  vh = YAML.load(File.read("VERSION.yml"))
  version = [vh[:major], vh[:minor], vh[:patch], vh[:build]].compact.join(".")
  pkgfile = File.join("pkg", "#{GEM_NAME}-#{version}.gem")
  Kernel.system("gem", "push", pkgfile)
end

desc "Generate RDoc documentation"
Rake::RDocTask.new(:rdoc) do |rdoc|
  rdoc.rdoc_dir = "doc"
  rdoc.title    = "SmartTuple"
  #rdoc.options << "--line-numbers"
  #rdoc.options << "--inline-source"
  rdoc.rdoc_files.include("lib/**/*.rb")
end

desc "Compile README preview"
task :readme do
  require "kramdown"

  doc = Kramdown::Document.new(File.read "README.md")

  fn = "README.html"
  puts "Writing '#{fn}'..."
  File.open(fn, "w") do |f|
    f.write(File.read "dev/head.html")
    f.write(doc.to_html)
  end
  puts ": ok"
end
