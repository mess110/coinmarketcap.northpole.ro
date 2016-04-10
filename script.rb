#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'
require 'fileutils'

current_folder = File.dirname(File.expand_path(__FILE__))
@path = File.join(current_folder, 'public', 'api')

cmc_data = open("http://coinmarketcap.com/all/views/all/")
@doc = Nokogiri::HTML(cmc_data)

# File.write('static.html', cmc_data.read)
# @doc = Nokogiri::HTML(File.read('static.html'))

@ts = Time.now.to_i
@currencies = ['usd', 'btc']
@exchange_currencies = ['usd', 'eur', 'cny', 'gbp', 'cad', 'rub', 'hkd', 'jpy', 'aud']

# order is important and KEEP ID AS THE LAST ELEMENT. you have been warned
@keys = ['position', 'name', 'symbol', 'category', 'marketCap', 'price', 'availableSupply', 'availableSupplyNumber', 'volume24', 'change1h', 'change7h', 'change7d', 'timestamp']

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

def to_v1_format coin, currency='usd'
  {
    "position"=> coin['position'],
    "name"=> coin['name'],
    "marketCap"=> coin['marketCap'][currency],
    "price"=> coin['price']['usd'],
    "totalSupply"=> coin['availableSupply'],
    "volume24"=> coin['volume24'][currency],
    "change24"=> "0.0 %",
    "change1h"=> coin['change1h'][currency],
    "change7h"=> coin['change7h'][currency],
    "change7d"=> coin['change7d'][currency],
    "timestamp"=> coin['timestamp'],
    "lowVolume"=> false,
    "id"=> coin['symbol'].downcase,
    "currency"=> currency
  }
end

def to_v2_format coin, currency='usd'
  to_v1_format(coin, currency)
end

def to_v4_format coin
  {
    position: coin['position'],
    name: coin['name'],
    marketCap: coin['marketCap'],
    price: coin['price'],
    totalSupply: coin['availableSupply'],
    volume24: coin['volume24'],
    change24: "0.0 %",
    change1h: coin['change1h'],
    change7h: coin['change7h'],
    change7d: coin['change7d'],
    timestamp: coin['timestamp'],
    lowVolume: false,
    id: coin['symbol'].downcase
  }
end

def write_one coin
  # version 1
  write("#{@path}/#{coin['symbol'].downcase}.json", to_v1_format(coin))

  # version 2
  @currencies.each do |currency|
    write("#{@path}/#{currency}/#{coin['symbol'].downcase}.json", to_v2_format(coin, currency))
  end

  write("#{@path}/v4/#{coin['symbol'].downcase}.json", to_v4_format(coin))

  # version 5
  coin_path = "#{@path}/v5/#{coin['symbol']}.json"
  write(coin_path, coin)
  write_history(coin)
end

def write_history coin
  time_at = Time.at(@ts)
  path = "#{@path}/v5/history/#{coin['symbol']}_#{time_at.year}.json"

  write(path, { 'symbol' => coin['symbol'], 'history' => {} }) unless File.exists?(path)

  hash = JSON.parse(File.read(path))
  key = time_at.strftime('%d-%m-%Y')
  unless hash['history'].key?(key)
    hash['history'][key] = coin
    write(path, hash)
  end
end

# writes all.json for all API versions.
def write_all coin
  # version 1
  h = {
    "timestamp"=> coin['timestamp'],
    "markets"=> []
  }
  coin['markets'].each do |c|
    h['markets'] << to_v1_format(c)
  end
  write("#{@path}/all.json", h)

  # version 2
  h = {
    "timestamp"=> coin['timestamp'],
    "markets"=> []
  }
  @currencies.each do |currency|
    coin['markets'].each do |c|
      h['markets'] << to_v2_format(c, currency)
    end
    write("#{@path}/#{currency}/all.json", h)
  end

  # version 4
  h = {
    "timestamp"=> coin['timestamp'],
    "markets"=> []
  }
  coin['markets'].each do |c|
    h['markets'] << to_v4_format(c)
  end
  write("#{@path}/v4/all.json", h)

  # version 5
  write("#{@path}/v5/all.json", coin)
end

def get_json_data table_id
  markets = []

  cer = @doc.css("#currency-exchange-rates")
  currency_exchange_rates = {}
  @exchange_currencies.each do |currency|
    currency_exchange_rates[currency] = cer.attribute("data-#{currency}").text.strip
  end

  # reverse is needed because
  # https://www.reddit.com/r/coinmarketcapjson/comments/2pqvwi/amazing_service_thank_you_very_much/cmz6sxr
  @doc.css("#{table_id} tbody tr").reverse.each do |tr|
    tds = tr.css('td')

    td_position = tds[0].text.strip
    td_name = tds[1].text.strip
    td_symbol = tds[2].text.strip
    begin
      td_category = tds[1].css('a')[0]['href'].include?('assets') ? 'asset' : 'currency'
    rescue
      td_category = '?'
    end
    td_market_cap = {}
    td_price = {}
    begin
      td_available_supply = tds[5].css('a').text.strip
      td_available_supply_number = td_available_supply.gsub(',','').to_i
    rescue
      td_available_supply = '?'
      td_available_supply_number = '?'
    end
    td_volume_24h = {}
    td_change_1h = {}
    td_change_24h = {}
    td_change_7d = {}

    @currencies.each do |currency|
      begin
        td_market_cap[currency] = tds[3].attribute("data-#{currency}").text.strip
      rescue
        td_market_cap[currency] = '?'
      end
      begin
        td_price[currency] = tds[4].css('a').attribute("data-#{currency}").text.strip
      rescue
        td_price[currency] = '?'
      end
      begin
        td_volume_24h[currency] = tds[6].css('a').attribute("data-#{currency}").text.strip
      rescue
        td_volume_24h[currency] = '0.0 %'
      end
      begin
        td_change_1h[currency] = tds[7].attribute("data-#{currency}").text.strip
      rescue
        td_change_1h[currency] = '?'
      end
      begin
        td_change_24h[currency] = tds[8].attribute("data-#{currency}").text.strip
      rescue
        td_change_24h[currency] = '?'
      end
      begin
        td_change_7d[currency] = tds[9].attribute("data-#{currency}").text.strip
      rescue
        td_change_7d[currency] = '?'
      end
    end

    def convert number, currency, currency_exchange_rates
      (number['usd'].to_f / currency_exchange_rates[currency].to_f).to_s rescue '?'
    end

    @exchange_currencies.each do |currency|
      td_market_cap[currency] = convert(td_market_cap, currency, currency_exchange_rates)
      td_price[currency] = convert(td_price, currency, currency_exchange_rates)
      td_volume_24h[currency] = '0.0 %'
      td_change_1h[currency] = td_change_1h['usd']
      td_change_24h[currency] = td_change_24h['usd']
      td_change_7d[currency] = td_change_7d['usd']
    end

    coin = [
      td_position,
      td_name,
      td_symbol,
      td_category,
      td_market_cap,
      td_price,
      td_available_supply,
      td_available_supply_number,
      td_volume_24h,
      td_change_1h,
      td_change_24h,
      td_change_7d,
      @ts,
    ]

    markets << Hash[@keys.zip(coin)]
  end

  { 'timestamp' => @ts, 'markets' => markets, 'currencyExchangeRates' => currency_exchange_rates }
end

def mkdir *strings
  FileUtils.mkdir_p File.join(strings)
end

mkdir(@path, 'btc')
mkdir(@path, 'usd')
mkdir(@path, 'v3')
mkdir(@path, 'v4')
mkdir(@path, 'v5')
mkdir(@path, 'v5/history')

json_data = get_json_data('#currencies-all')

json_data['markets'].each do |h|
  write_one h
end
write_all json_data
