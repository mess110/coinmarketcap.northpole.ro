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
@currencies = ['usd', 'btc', 'eur', 'cny', 'gdp', 'cad', 'rub']

# order is important and KEEP ID AS THE LAST ELEMENT. you have been warned
@keys = ['position', 'name', 'marketCap', 'price', 'totalSupply', 'volume24', 'change24', 'timestamp', 'lowVolume', 'id']

# converts a coin to the old json format
def old_format coin, currency
  coin['currency'] = currency
  ['marketCap', 'price', 'volume24'].each do |key|
    begin
      coin[key] = coin[key][currency]
    rescue
      coin[key] = ''
    end
  end

  coin
end

# converts all coins in hash['markets'] to old json format
def old_format_all coins, currency
  old_formatted_coins = {
    timestamp: coins['timestamp'],
    markets: []
  }
  coins['markets'].each do |market|
    old_formatted_coins[:markets].push old_format(market, currency)
  end
  old_formatted_coins
end

def write_one coin
  mkdir(@path, 'first_crawled')

  @currencies.each do |currency|
    h = old_format(coin.clone, currency)

    mkdir(@path, currency)
    mkdir(@path, 'v3', currency)

    # version 1
    File.open("#{@path}/#{h['id']}.json",'w') { |f| f.write(h.to_json) } if currency == 'usd'

    # version 2
    currency_path = "#{@path}/#{currency}/#{h['id']}.json"
    File.open("#{@path}/first_crawled/#{h['id']}.json",'w') { |f| f.write(h.to_json) } if !File.exists?(currency_path) && currency == 'usd'
    File.open(currency_path,'w') { |f| f.write(h.to_json) }

    # version 3
    currency_path = "#{@path}/v3/#{currency}/#{h['id']}.json"
    File.open(currency_path,'w') { |f| f.write(h.to_json) }
  end

  # version 4
  mkdir(@path, 'v4')
  coin_path = "#{@path}/v4/#{coin['id']}.json"
  File.open(coin_path, 'w') { |f| f.write(coin.to_json) }
end

def write_all coin

  @currencies.each do |currency|
    h = old_format_all(coin.clone, currency)

    # version 1
    File.open("#{@path}/all.json",'w') {|f| f.write(h.to_json) } if currency == 'usd'

    # version 2
    File.open("#{@path}/#{currency}/all.json",'w') {|f| f.write(h.to_json) }

    # version 3
    File.open("#{@path}/v3/#{currency}/all.json",'w') {|f| f.write(h.to_json) }
  end

  # version 4
  File.open("#{@path}/v4/all.json",'w') {|f| f.write(coin.to_json) }
end

def get_json_data table_id
  markets = []
  @doc.css("#{table_id} tbody tr").each do |tr|
    tds = tr.css('td')

    td2 = {}
    td3 = {}
    td5 = {}

    @currencies.each do |currency|
      begin
        td2[currency] = tds[2].attribute("data-#{currency}").text.strip
      rescue
        td2[currency] = ''
      end
      begin
        td3[currency] = tds[3].css('a').attribute("data-#{currency}").text.strip
      rescue
        td3[currency] = ''
      end
      begin
        td5[currency] = tds[5].css('a').attribute("data-#{currency}").text.strip
      rescue
        td5[currency] = ''
      end
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
      table_id == '#low-volume-currencies',
      ''
    ]
    coin[-1] = tr.attribute('id').text # this is why the id should be the last element
    markets << Hash[@keys.zip(coin)]
  end

  { 'timestamp' => @ts, 'markets' => markets }
end

def mkdir *strings
  FileUtils.mkdir_p File.join(strings)
end

json_data = get_json_data('#currencies')
low_volume_json_data = get_json_data('#low-volume-currencies')
json_data['markets'].push(*low_volume_json_data['markets'])

json_data['markets'].each do |h|
  write_one h
end
write_all json_data
