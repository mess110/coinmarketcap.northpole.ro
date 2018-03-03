#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'date'

def expect a, b, message = 'error'
  fail message if a != b
end

def json_req url
  req = open(url)
  JSON.parse(req.read)
end

def expect_recent_timestamp timestamp
  ts = Time.at(timestamp)
  fail 'timestamp not updated in the last 20 minutes' if Time.now - ts > 20 * 60
  ts
end

def expect_recent url
  json = json_req url
  expect_recent_timestamp(json['timestamp'])
end

def expect_history url
  json = json_req url
  fail 'not a history file' if json['history'].empty?
end

start_time = Time.now
puts 'Checking http'
expect_recent 'http://coinmarketcap.northpole.ro/api/v8/bitcoin.json'

puts 'Checking https'
expect_recent 'https://coinmarketcap.northpole.ro/api/v8/dogecoin.json'

puts 'Checking coins.json'
json_req 'https://coinmarketcap.northpole.ro/coins.json'

puts 'Checking ticker.json'
btc_timestamp = expect_recent 'http://coinmarketcap.northpole.ro/ticker.json?identifier=bitcoin'

puts 'Checking history.json'
expect_history 'https://coinmarketcap.northpole.ro/history.json?coin=bitcoin'

puts 'Checking saturn.json'
json_req 'https://coinmarketcap.northpole.ro/saturn.json'

puts "Ran for #{(Time.now - start_time).round(2)} seconds"
puts "Last run was at #{btc_timestamp}"
puts 'ok'
