require 'rspec/core/rake_task'
require 'json'

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

  desc 'get all versions of the report and concatenate it'
  task :full_report do
    data = []
    report = {}

    revisions = `git rev-list --all --objects -- public/report.js`.split("\n")
    revisions.each do |revision|
      key = revision.split(' ')[0]
      output = `git show #{key}`
      if output.start_with?('var GRAPH')

        output.gsub!('var GRAPH = ', '')
        output.gsub!(';', '')

        json = JSON.parse(output)
        json.each do |e|
          if e.class == Array
            data.push({
              'x' => e[0],
              'y' => e[1]
            })
          else
            data.push e
          end
        end
      end
    end

    data.each do |d|
      if report.key?(d['x']) && report[d['x']] != d['y']
        if report[d['x']] < d['y']
          report[d['x']] = d['y']
        end
      else
        report[d['x']] = d['y']
      end
    end

    s = 'var GRAPH = ['
    report.keys.sort.each do |key|
      if Time.at(key).hour == 0
        s += "{ \"x\": #{key},\"y\": #{report[key]}},"
      end
    end
    s = s[0...-1]
    s += '];'

    File.write('public/full_report.js', s)
  end

  desc 'count total api calls'
  task :count_total do
    report = File.read('public/full_report.js')
    report.gsub!('var GRAPH = ', '')
    report.gsub!(';', '')
    puts JSON.parse(report).map{ |e| e['y'] }.inject(:+)
  end
end

task :default => :spec
