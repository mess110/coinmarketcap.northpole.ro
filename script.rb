#!/usr/bin/env ruby

require 'open-uri'
require 'json'
require 'nokogiri'
require 'pp'
require 'fileutils'
require 'bigdecimal'
require 'logger'


current_folder = File.dirname(File.expand_path(__FILE__))
BASE_PATH = File.join(current_folder, 'public', 'api')
# order is important because we zip this
COIN_KEYS = ['position', 'name', 'symbol', 'identifier', 'category', 'marketCap', 'price', 'availableSupply', 'availableSupplyNumber', 'volume24', 'change1h', 'change7h', 'change7d', 'timestamp', 'coinLogoId']
CURRENCIES = ['usd', 'btc']
EXCHANGE_CURRENCIES = %w(usd aud brl cad chf clp cny czk dkk eur gbp hkd huf idr ils inr jpy krw mxn myr nok nzd php pkr pln rub sek sgd thb try twd zar)
LOGO_SIZES = %w(16x16 32x32 64x64 128x128)
@write_count = {
  fail: 0,
  success: 0
}

@logger = Logger.new(File.join(current_folder, 'logs', 'script.log'), 'weekly')
@logger.level = Logger::INFO
cmc_data = open("https://coinmarketcap.com/all/views/all/")
@doc = Nokogiri::HTML(cmc_data)

@ts = Time.now.to_i

# converts a coin to the old json format
def old_format coin, currency
  coin['currency'] = currency
  ['marketCap', 'price', 'volume24'].each do |key|
    coin[key] = coin[key][currency]
  end

  coin
end

def convert number, currency, currency_exchange_rates
  (BigDecimal(number['usd'].to_s) / BigDecimal(currency_exchange_rates[currency].to_s)).to_f.to_s rescue '?'
end

def write path, hash
  File.open(path,'w') { |f| f.write(hash.to_json) }
  @write_count[:success] += 1
  @logger.debug "Success: #{path}"
rescue => e
  @write_count[:fail] += 1
  @logger.error "could not write #{path}"
  @logger.debug e.backtrace
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

def to_general_number n
  return nil if n == '?' || n == nil
  n.to_f
end

def to_v6_format coin
  coin_clone = coin.clone
  coin_clone.delete('coinLogoId')

  # this will ensure the order
  coin_clone['change24h'] = coin_clone.delete('change7h')
  coin_clone['change7d'] = coin_clone.delete('change7d')
  coin_clone['timestamp'] = coin_clone.delete('timestamp')

  coin_clone['change1h'] = to_general_number(coin_clone['change1h']['usd'])
  coin_clone['change24h'] = to_general_number(coin_clone['change24h']['usd'])
  coin_clone['change7d'] = to_general_number(coin_clone['change7d']['usd'])
  coin_clone['availableSupply'] = coin_clone.delete('availableSupplyNumber')

  coin_clone['position'] = coin_clone['position'].to_i

  ['marketCap', 'price'].each do |key|
    coin_clone[key].keys.each do |currency|
      coin_clone[key][currency] = to_general_number(coin_clone[key][currency])
    end
  end
  coin_clone['volume24'].keys.each do |currency|
    bd_price_currency = coin_clone['price'][currency].to_s
    bd_price_currency = '0' if bd_price_currency == '' || bd_price_currency.nil?

    bd_price_btc = coin_clone['price']['btc'].to_s
    bd_price_btc = '0' if bd_price_btc == '' || bd_price_btc.nil?

    bd_volume24_btc = coin_clone['volume24']['btc'].to_s
    bd_volume24_btc = '0' if bd_volume24_btc == '' || bd_volume24_btc.nil? || bd_volume24_btc == 'None'

    btc_price = BigDecimal(bd_price_currency) / BigDecimal(bd_price_btc)
    coin_clone['volume24'][currency] = btc_price.nan? ? 0.to_f : (BigDecimal(bd_volume24_btc) * btc_price).to_f
  end

  coin_clone
end

def write_one coin
  # version 1
  write("#{BASE_PATH}/#{coin['symbol'].downcase}.json", to_v1_format(coin))

  v6_coin = to_v6_format(coin)

  # version 8
  return if coin['identifier'].nil?
  coin_path = "#{BASE_PATH}/v8/#{coin['identifier']}.json"
  write(coin_path, v6_coin)
  write_history(v6_coin, v6_coin['identifier'], 'v8')
  write_hourly(v6_coin, v6_coin['identifier'], 'v8')
end

def write_hourly coin, path_key, vkey
  time_at = Time.at(@ts)
  path = "#{BASE_PATH}/#{vkey}/history/#{path_key}_14days.json"
  hash = read_history_path(path, coin)
  key = time_at.strftime('%H-%d-%m-%Y')
  added = ahistory hash, key, coin, path

  removed = false
  while hash['history'].keys.size > 24 * 14
    removed = true
    hash['history'].delete(hash['history'].keys.first)
  end
  if added || removed
    write(path, hash)
  end
rescue => e
  @logger.error "write_hourly #{coin['identifier']}: #{path}"
  @logger.debug e.backtrace
end

def write_history coin, path_key, vkey
  time_at = Time.at(@ts)
  path = "#{BASE_PATH}/#{vkey}/history/#{path_key}_#{time_at.year}.json"
  hash = read_history_path(path, coin)
  key = time_at.strftime('%d-%m-%Y')
  if ahistory hash, key, coin, path
    write(path, hash)
  end
rescue => e
  @logger.error "write_history #{coin['symbol']}: #{path}"
  @logger.debug e.backtrace
end

def read_history_path(path, coin)
  if file_ok?(path)
    JSON.parse(File.read(path))
  else
    { 'symbol' => coin['symbol'], 'identifier' => coin['identifier'], 'history' => {} }
  end
end

def file_ok? path
  File.exists?(path) && !File.zero?(path) && File.size?(path) > 10
end

def ahistory hash, key, coin, path
  if hash['history'].key?(key)
    # we want to keep the "stronger" coin
    if hash['history'][key]['name'] != coin['name']
      hash['history'][key] = coin
      return true
    end
    return false
  else
    hash['history'][key] = coin
    return true
  end
  false
end

# writes all.json for all API versions.
def write_all coins
  # version 1
  h = {
    "timestamp"=> coins['timestamp'],
    "markets"=> []
  }
  coins['markets'].each do |c|
    h['markets'] << to_v1_format(c)
  end
  write("#{BASE_PATH}/all.json", h)

  # version 8
  all_clone = coins.clone
  all_clone['markets'] = all_clone['markets'].map { |e| to_v6_format(e) }
  write("#{BASE_PATH}/v8/all/all.json", all_clone)
end

def get_global_data markets
  btc = markets.select { |e| e['symbol'] == 'BTC' }.first
  btc_price = btc['price']['usd'].to_f

  total_market_cap = markets.collect{ |e| e["marketCap"]["usd"].to_f }.inject(:+)
  total_24h_volume = markets.collect{|e| e["volume24"]["btc"].to_f }.inject(:+) * btc_price
  bitcoin_percent_of_mktcap = (btc['marketCap']['usd'].to_f * 100 / total_market_cap).round(2)

  return {
    total_market_cap: total_market_cap,
    total_24h_volume: total_24h_volume,
    bitcoin_percent_of_market_cap: bitcoin_percent_of_mktcap,
    active_currencies: markets.select { |e| e['category'] == 'currency' }.count,
    active_assets: markets.select { |e| e['category'] == 'asset' }.count
  }
end

def get_json_data table_id
  markets = []

  cer = @doc.css("#currency-exchange-rates")
  currency_exchange_rates = {}
  EXCHANGE_CURRENCIES.each do |currency|
    currency_exchange_rates[currency] = cer.attribute("data-#{currency}").text.strip
  end

  # reverse is needed because
  # https://www.reddit.com/r/coinmarketcapjson/comments/2pqvwi/amazing_service_thank_you_very_much/cmz6sxr
  @doc.css("#{table_id} tbody tr").reverse.each do |tr|

    tr_identifier = (tr.attr('id') || '')[3..-1] # can be nil

    tds = tr.css('td')

    td_position = tds[0].text.strip

    begin
      coin_logo = tds[1].children[1].attr('class').split(' ')[0].split('-').last
    rescue
      coin_logo = nil
    end

    begin
      td_name = tds[1].css('a')[1].text.strip
    rescue
      td_name = tds[1].text.strip
    end

    td_symbol = tds[2].text.strip
    begin
      td_category = tds[1].css('a')[0]['href'].include?('assets') ? 'asset' : 'currency'
    rescue
      td_category = '?'
    end
    td_market_cap = {}
    td_price = {}
    begin
      td_available_supply = tds[5].css('span').attribute('data-supply').text.strip
      td_available_supply_number = td_available_supply.gsub(',','').to_i
    rescue
      td_available_supply = '?'
      td_available_supply_number = '?'
    end
    td_volume_24h = {}
    td_change_1h = {}
    td_change_24h = {}
    td_change_7d = {}

    CURRENCIES.each do |currency|
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
        td_change_1h[currency] = tds[7].attribute("data-percent#{currency}").text.strip
      rescue
        td_change_1h[currency] = '?'
      end
      begin
        td_change_24h[currency] = tds[8].attribute("data-percent#{currency}").text.strip
      rescue
        td_change_24h[currency] = '?'
      end
      begin
        td_change_7d[currency] = tds[9].attribute("data-percent#{currency}").text.strip
      rescue
        td_change_7d[currency] = '?'
      end
    end

    EXCHANGE_CURRENCIES.each do |currency|
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
      tr_identifier,
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
      coin_logo
    ]

    markets << Hash[COIN_KEYS.zip(coin)]
  end

  { 'timestamp' => @ts, 'markets' => markets, 'currencyExchangeRates' => currency_exchange_rates, 'global' => get_global_data(markets) }
end

def mkdir *strings
  FileUtils.mkdir_p File.join(strings)
end

def mkdirs
  mkdir(BASE_PATH, 'btc')
  mkdir(BASE_PATH, 'usd')
  mkdir(BASE_PATH, 'v8')
  mkdir(BASE_PATH, 'v8/all')
  mkdir(BASE_PATH, 'v8/history')
  mkdir(BASE_PATH, 'v8/logos')
  LOGO_SIZES.each do |size|
    mkdir(BASE_PATH, 'v8/logos', size)
  end
end

def run_script
  @logger.info "Starting script at #{Time.at(@ts)}"
  mkdirs
  json_data = get_json_data('#currencies-all')

  json_data['markets'].each do |h|
    write_one h
    # write_one h if h['symbol'] == 'BTC'
  end
  write_all json_data

  now = Time.now
  @logger.info "Wrote #{@write_count[:success]} times and failed #{@write_count[:fail]} times."
  @logger.info "script_is_finished #{(now - @ts).to_i}"
  @logger.info "Script finished at #{now}. (#{(now - @ts).to_i} seconds)"
end

def dl_logos
  @logger.info "Starting dl_logos at #{Time.at(@ts)}"
  mkdirs
  json_data = get_json_data('#currencies-all')

  json_data['markets'].each do |h|
    LOGO_SIZES.each do |size|
      logo_url = "https://files.coinmarketcap.com/static/img/coins/#{size}/#{h['coinLogoId']}.png"
      logo_path = File.join(BASE_PATH, 'v8', 'logos', size, "#{h['identifier']}.png")

      open(logo_path, 'wb') do |file|
        @logger.debug "Download logo for #{h['identifier']} (#{size})"
        file << open(logo_url).read
      end
    end
  end

  now = Time.now
  @logger.info "gl_logos finished at #{now}. (#{(now - @ts).to_i} seconds)"
end

def help
  puts <<-EOF
This is the CLI which gathers all the data from coinmarketcap.com

List of commands:

  * run - queries coinmarketcap.com, parses the data and writes it to disk
  * logos - download all logos from coinmarketcap.com
  * help - this text

Example usage:

  ./script.rb
  ./script.rb run
  ruby script.rb run

  EOF
end

if ARGV.empty?
  run_script
else
  case ARGV[0]
  when 'run'
    run_script
  when 'logos'
    dl_logos
  else
    help
  end
end
