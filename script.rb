#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'

current_folder = File.dirname(File.expand_path(__FILE__))
path = File.join(current_folder, 'public', 'api')

doc = Nokogiri::HTML(open("http://coinmarketcap.com/"))
# File.open('coinmarketcap','w') {|f| doc.write_html_to f}
# doc = Nokogiri::HTML(File.open('coinmarketcap', 'r'))

ts = Time.now.to_i
# order is important
keys = ['position','name','marketCap','price','totalSupply','volume24','change24', 'id']

r = []
doc.css("#currencies tbody tr").each do |tr|
  coin = tr.css('td').collect{ |td| td.text.strip.gsub('*','') }
  coin[-1] = tr.attribute('id').text
  h = Hash[keys.zip(coin)]
  h['timestamp'] = Time.now.to_i
  File.open("#{path}/#{coin[-1]}.json",'w') { |f| f.write(h.to_json) }
  h.delete('timestamp')
  r << h
end

rr = { 'timestamp' => ts, 'markets' => r }
File.open("#{path}/all.json",'w') {|f| f.write(rr.to_json) }
