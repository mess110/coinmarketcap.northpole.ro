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
  fail 'timestamp not updated in the last 10 minutes' if Time.now - ts > 10 * 60
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


expect_recent 'http://coinmarketcap.northpole.ro/api/doge.json'
expect_recent 'http://coinmarketcap.northpole.ro/api/v5/DOGE.json'
expect_history 'http://coinmarketcap.northpole.ro/api/v5/history/DOGE_2016.json'
btc_timestamp = expect_recent 'http://coinmarketcap.northpole.ro/ticker.json?identifier=bitcoin'

puts "Last run was at #{btc_timestamp}"
puts 'ok'
