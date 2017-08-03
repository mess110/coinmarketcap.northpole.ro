#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'date'

def btc_timestamp
  req = open("http://coinmarketcap.northpole.ro/ticker.json?identifier=bitcoin")
  json = JSON.parse(req.read)
  Time.at(json['timestamp'])
end

puts "Last run was at #{btc_timestamp}"
