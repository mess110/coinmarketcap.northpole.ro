require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

namespace :generate do
  desc "generate doc"
  task :doc do
    puts 'generating documentation and html'
    require './generate_doc.rb'
  end

  desc "generate usage report"
  task :report do
    puts 'genearting report. this will take some time'
    require './generate_report.rb'
  end
end

task :default => :spec
