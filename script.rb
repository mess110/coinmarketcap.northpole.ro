#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'

current_folder = File.dirname(File.expand_path(__FILE__))
@path = File.join(current_folder, 'public', 'api')

@doc = Nokogiri::HTML(open("http://coinmarketcap.com/"))
# File.open('coinmarketcap','w') {|f| @doc.write_html_to f}
# @doc = Nokogiri::HTML(File.open('coinmarketcap', 'r'))

@ts = Time.now.to_i

# order is important
@keys = ['position', 'name', 'marketCap', 'price', 'totalSupply', 'volume24', 'change24', 'timestamp', 'currency', 'id']

def write_to_disk currency
  r = []
  @doc.css("#currencies tbody tr").each do |tr|
    tds = tr.css('td')
    coin = [
      tds[0].text.strip,
      tds[1].text.strip,
      tds[2].attribute("data-#{currency}").text.strip,
      tds[3].css('a').attribute("data-#{currency}").text.strip,
      tds[4].text.strip.gsub('*', ''),
      tds[5].css('a').attribute("data-#{currency}").text.strip,
      tds[6].text.strip,
      @ts,
      currency,
      ''
    ]
    coin[-1] = tr.attribute('id').text
    h = Hash[@keys.zip(coin)]
    File.open("#{@path}/#{currency}/#{coin[-1]}.json",'w') { |f| f.write(h.to_json) }
    File.open("#{@path}/#{coin[-1]}.json",'w') { |f| f.write(h.to_json) } if currency == 'usd'
    r << h
  end

  rr = { 'timestamp' => @ts, 'markets' => r }
  File.open("#{@path}/#{currency}/all.json",'w') {|f| f.write(rr.to_json) }
  File.open("#{@path}/all.json",'w') {|f| f.write(rr.to_json) } if currency == 'usd'
end

write_to_disk 'usd'
write_to_disk 'btc'
