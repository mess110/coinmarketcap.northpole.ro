#!/usr/bin/env ruby
# encoding: utf-8

require 'json'
require 'date'

puts 'getting logs'
if `hostname`.chomp == 'northpole'
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
