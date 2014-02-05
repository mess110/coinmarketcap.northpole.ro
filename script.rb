#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'

doc = Nokogiri::HTML(open("http://coinmarketcap.com/"))
# File.open('coinmarketcap','w') {|f| doc.write_html_to f}
# doc = Nokogiri::HTML(File.open('coinmarketcap', 'r'))

r = []
doc.css("#currencies tbody tr").each do |tr|
  coin = tr.css('td').collect{ |td| td.text.strip.gsub('*','') }
  coin[-1] = tr.attribute('id').text

  keys = ['position','name','marketCap','price','totalSupply','volume24','change24', 'id']
  h = Hash[keys.zip(coin)]
  File.open("public/api/#{coin[-1]}.json",'w') {|f| f.write(h.to_json) }
  r << h
end

File.open('public/api/all.json','w') {|f| f.write(r.to_json) }
