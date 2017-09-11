require 'rspec/core/rake_task'
require 'json'
require 'redcarpet'
require 'date'

RSpec::Core::RakeTask.new(:spec)

def production?
  `hostname`.chomp == 'northpole'
end

def read path
  File.read(path)
end

namespace :generate do
  desc 'generate doc'
  task :doc do
    puts 'generating documentation and html'
    def generate file, content, method
      File.open(file, method) { |f| f.write(content) }
    end

    def render_html input, output
      html = @markdown.render(read(input))

      unless production?
        html.gsub!('//coinmarketcap.northpole.ro', '')
      end

      generate(output, read('views/top.html'), 'w')
      generate(output, html, 'a')
      generate(output, read('views/bottom.html'), 'a')
    end

    renderer = Redcarpet::Render::HTML
    @markdown = Redcarpet::Markdown.new(renderer, autolink: true, tables: true)

    render_html 'README.md', 'public/index.html'
    render_html 'BACKWARD_COMPATIBILITY.md', 'public/doc.html'
  end

  desc 'generate usage report - after it is committed, run generate:full_report'
  task :report do
    puts 'genearting report. this will take some time'
    puts 'getting logs'
    if production?
      puts 'production environment detected'
      `scp -p /var/log/apache2/other_*.gz tmp/logs/`
    else
      puts 'development environment detected'
      `scp -p kiki@northpole.ro:/var/log/apache2/other_*.gz tmp/logs/`
    end

    puts 'extracting archives'
    `gunzip --force tmp/logs/*.gz`

    def mtime s
      File.open(s).mtime
    end

    web_name = 'www.coinmarketcap.northpole.ro:80'
    result = []

    puts 'processing logs'
    logs = Dir['tmp/logs/*log*'].sort!{|a,b| mtime(a) <=> mtime(b) }
    logs.each do |path|
      log_file = File.open(path)
      api_calls = log_file.each_line.select { |l| l.start_with?(web_name) }
      api_calls = api_calls.select { |l| l.include?('json') }
      result << { x: log_file.mtime.to_i, y: api_calls.count }
    end

    puts 'formatting report'
    r = {}
    result.each do |a|
      seconds_since_epoc_integer = a[:x]
      date = Time.at(seconds_since_epoc_integer)
      date_group_str = date.strftime("%Y-%m")
      r[date_group_str] = 0 unless r.key?(date_group_str)
      r[date_group_str] += a[:y]
    end

    result = r.to_a.map{|e|
      dc = e[0].split('-')
      date = Date.strptime("{ #{dc[0]}, #{dc[1]}, 1 }", "{ %Y, %m, %d }")
      { x: date.to_time.to_i, y: e[1] }
    }

    puts 'writing public/report.js'
    output_path = File.join(Dir.pwd, 'public', 'report.js')
    File.open(output_path, 'w') {|f| f.write('var GRAPH = ' + result.to_json + ';') }
  end

  desc 'get all versions of the report and concatenate them'
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
    report = read('public/full_report.js')
    report.gsub!('var GRAPH = ', '')
    report.gsub!(';', '')
    puts JSON.parse(report).map{ |e| e['y'] }.inject(:+)
  end
end

task :default => :spec
