#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'
require 'fileutils'

current_folder = File.dirname(File.expand_path(__FILE__))
@path = File.join(current_folder, 'public', 'api')

@doc = Nokogiri::HTML(open("http://coinmarketcap.com/all.html"))
# File.open('coinmarketcap','w') {|f| @doc.write_html_to f}
# @doc = Nokogiri::HTML(File.open('coinmarketcap', 'r'))

@ts = Time.now.to_i

# order is important and KEEP ID AS THE LAST ELEMENT. you have been warned
@keys = ['position', 'name', 'marketCap', 'price', 'totalSupply', 'volume24', 'change24', 'timestamp', 'currency', 'lowVolume', 'id']

def write_one h, currency
  File.open("#{@path}/#{h['id']}.json",'w') { |f| f.write(h.to_json) } if currency == 'usd'

  currency_path = "#{@path}/#{currency}/#{h['id']}.json"
  File.open("#{@path}/first_crawled/#{h['id']}.json",'w') { |f| f.write(h.to_json) } if !File.exists?(currency_path) && currency == 'usd'
  File.open(currency_path,'w') { |f| f.write(h.to_json) }
end

def write_all h, currency
  File.open("#{@path}/all.json",'w') {|f| f.write(h.to_json) } if currency == 'usd'
  File.open("#{@path}/#{currency}/all.json",'w') {|f| f.write(h.to_json) }
end

def get_json_data table_id, currency
  markets = []
  @doc.css("#{table_id} tbody tr").each do |tr|
    tds = tr.css('td')

    # TODO clean this up
    begin
      td2 = tds[2].attribute("data-#{currency}").text.strip
    rescue
      td2 = ''
    end
    begin
      td3 = tds[3].css('a').attribute("data-#{currency}").text.strip
    rescue
      td3 = ''
    end
    begin
      td5 = tds[5].css('a').attribute("data-#{currency}").text.strip
    rescue
      td5 = ''
    end

    coin = [
      tds[0].text.strip,
      tds[1].text.strip,
      td2,
      td3,
      tds[4].text.strip.gsub('*', ''),
      td5,
      tds[6].text.strip,
      @ts,
      currency,
      table_id == '#low-volume-currencies',
      ''
    ]
    coin[-1] = tr.attribute('id').text # this is why the id should be the last element
    markets << Hash[@keys.zip(coin)]
  end

  { 'timestamp' => @ts, 'markets' => markets }
end

['usd', 'btc', 'eur', 'cny', 'gdp', 'cad', 'rub'].each do |currency|
  FileUtils.mkdir_p File.join(@path, currency)

  json_data = get_json_data('#currencies', currency)
  low_volume_json_data = get_json_data('#low-volume-currencies', currency)
  json_data['markets'].push(*low_volume_json_data['markets'])
  json_data['markets'].each do |h|
    write_one h, currency
  end
  write_all json_data, currency
end
