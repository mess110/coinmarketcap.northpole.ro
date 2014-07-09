#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'
require 'fileutils'

current_folder = File.dirname(File.expand_path(__FILE__))
@path = File.join(current_folder, 'public', 'api')

@doc = Nokogiri::HTML(open("http://coinmarketcap.com/all.html"))

@ts = Time.now.to_i
@currencies = ['usd', 'btc']

# order is important and KEEP ID AS THE LAST ELEMENT. you have been warned
@keys = ['position', 'name', 'symbol', 'marketCap', 'price', 'availableSupply', 'volume24', 'cange1h', 'change7h', 'change7d', 'timestamp']

# converts a coin to the old json format
def old_format coin, currency
  coin['currency'] = currency
  ['marketCap', 'price', 'volume24'].each do |key|
    coin[key] = coin[key][currency]
  end

  coin
end

def write path, hash
  File.open(path,'w') { |f| f.write(hash.to_json) }
end

# converts all coins in hash['markets'] to old json format
def old_format_all coins, currency
  old_formatted_coins = {
    timestamp: coins['timestamp'],
    markets: []
  }
  coins['markets'].each do |market|
    old_formatted_coins[:markets].push old_format(market.clone, currency)
  end
  old_formatted_coins
end

def write_one coin
  # version 5
  mkdir(@path, 'v5')
  coin_path = "#{@path}/v5/#{coin['symbol']}.json"
  write(coin_path, coin)
end

def write_all coin
  # version 5
  write("#{@path}/v5/all.json", coin)
end

def get_json_data table_id
  markets = []
  @doc.css("#{table_id} tbody tr").each do |tr|
    tds = tr.css('td')

    td_position = tds[0].text.strip
    td_name = tds[1].text.strip
    td_symbol = tds[2].text.strip
    td_market_cap = {}
    td_price = {}
    td_available_supply = tds[5].css('a').text.strip
    td_volume_24h = {}
    td_change_1h = {}
    td_change_24h = {}
    td_change_7d = {}

    @currencies.each do |currency|
      begin
        td_market_cap[currency] = tds[3].attribute("data-#{currency}").text.strip
      rescue
        td_market_cap[currency] = ''
      end
      begin
        td_price[currency] = tds[4].css('a').attribute("data-#{currency}").text.strip
      rescue
        td_price[currency] = ''
      end
      begin
        td_volume_24h[currency] = tds[6].css('a').attribute("data-#{currency}").text.strip
      rescue
        td_volume_24h[currency] = ''
      end
      begin
        td_change_1h[currency] = tds[7].attribute("data-#{currency}").text.strip
      rescue
        td_change_1h[currency] = ''
      end
      begin
        td_change_24h[currency] = tds[8].attribute("data-#{currency}").text.strip
      rescue
        td_change_24h[currency] = ''
      end
      begin
        td_change_7d[currency] = tds[9].attribute("data-#{currency}").text.strip
      rescue
        td_change_7d[currency] = ''
      end
    end

    coin = [
      td_position,
      td_name,
      td_symbol,
      td_market_cap,
      td_price,
      td_available_supply,
      td_volume_24h,
      td_change_1h,
      td_change_24h,
      td_change_7d,
      @ts,
    ]

    markets << Hash[@keys.zip(coin)]
  end

  { 'timestamp' => @ts, 'markets' => markets }
end

def mkdir *strings
  FileUtils.mkdir_p File.join(strings)
end

json_data = get_json_data('#currencies-all')

json_data['markets'].each do |h|
  write_one h
end
write_all json_data
