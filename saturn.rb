#!/usr/bin/env ruby

# this scripts should take you to the Moon, but if you miss, it will take you
# to Saturn

require 'json'
require 'nokogiri'
require 'net/http'
require 'open-uri'
require 'fileutils'

DAY = 60 * 60 * 24
CURRENT_FOLDER = File.dirname(File.expand_path(__FILE__))

def read coin
  output = nil

  coin[:paths].each do |path|
    json = JSON.parse(File.read(path))
    if output.nil?
      output = json
    else
      output['history'].merge!(json['history'])
    end
  end

  output
rescue => e
  puts "saturn.rb: Error #{e} parsing #{coin['symbol']}"
  return {'history' => {}}
end

def req url
  url = URI.parse(url)
  puts url
  reqs = Net::HTTP::Get.new(url.to_s)
  res = Net::HTTP.start(url.host, url.port) { |http|
    http.request(reqs)
  }
  JSON.parse(res.body)
rescue => e
  puts "saturn.rb: Error #{e} requesting #{url}"
  {}
end

def write path, json
  File.open(path, 'w') do |f|
    f.write(json.to_json)
  end
end

def mkdir *strings
  FileUtils.mkdir_p File.join(strings)
end

def run_script
  timestamp = Time.now.to_i
  puts "Starting script at #{Time.at(timestamp)}"

  base_path = File.join(CURRENT_FOLDER, 'public/api/v8/history/')
  output_path = File.join(CURRENT_FOLDER, 'saturn.json')

  years = (2016..Time.now.year).to_a
  target_days_ago = [1, 2, 3, 14, 30, 60, 90, 120, 150, 180, 365]

  coins = Dir["#{base_path}*.json"].map do |e|
    e.split('/').last.split('_').first
  end.uniq.map do |e|
    coin = {
      symbol: e,
      paths: []
    }
    years.each do |year|
      target_path = "#{base_path}#{e}_#{year}.json"
      coin[:paths].push target_path if File.exist?(target_path)
    end

    coin
  end

  output = {
    timestamp: timestamp,
    timestampFriendly: Time.at(timestamp),
    currency: 'USD',
    total: coins.size,
    active_currencies: 0,
    active_assets: 0,
    coins: {}
  }

  coins.each do |coin|
    all_history = read(coin)

    # TODO: what if no history
    meta = all_history['history'].values.last

    next if meta.nil?

    case meta['category']
    when 'currency'
      output[:active_currencies] += 1
    when 'asset'
      output[:active_assets] += 1
    end

    coin_hash = {
      name: meta['name'],
      symbol: meta['symbol'],
      identifier: meta['identifier'],
      category: meta['category'],
      price: {}
    }

    target_days_ago.each do |day_ago|
      time_at = Time.at(timestamp - DAY * day_ago).strftime('%d-%m-%Y')

      begin
        price = all_history['history'][time_at]['price']['usd']
      rescue
        price = 'NA'
      end
      coin_hash[:price]["#{day_ago}day"] = price
    end

    output[:coins][coin[:symbol]] = coin_hash
  end

  File.open(output_path, 'w') { |f| f.write(output.to_json) }

  now = Time.now
  compressed_file_size = (File.size(output_path).to_f / 2**20).round(2)
  puts "#{output_path} written. Size: #{compressed_file_size}MB"
  puts "Script finished at #{now}. (#{(now - timestamp).to_i} seconds)"
end

def download_history
  if ARGV.length != 2
    fail 'missing backup path'
  end

  local_path = File.join(ARGV[1], 'api/v8/history/')

  mkdir(CURRENT_FOLDER, local_path)
  url = 'http://coinmarketcap.northpole.ro/'
  # url = 'http://localhost:1337/'
  timestamp = Time.now.to_i
  puts "Starting script at #{Time.at(timestamp)}"
  puts "Using #{local_path}"

  coins = req("#{url}coins.json")
  puts "Found #{coins['coins'].length} coins and #{coins['coins'].collect { |e| e['periods'] }.flatten.length} files."
  coins['coins'].each do |coin|
    coin['periods'].each do |period|
      new_path = "#{local_path}#{coin['identifier']}_#{period}.json"
      json = req("#{url}history.json?coin=#{coin['identifier']}&period=#{period}&format=hash")
      write(new_path, json)
    end
  end

  now = Time.now
  puts "Script finished at #{now}. (#{(now - timestamp).to_i} seconds)"
end

def convert_to_number td
  val = td.gsub(',', '')
  return nil if val == '-'
  val.to_i
end

def fill_blanks
  identifier = 'bitcoin'

  url = "https://coinmarketcap.com/currencies/#{identifier}/historical-data/?start=20130428&end=20170822"
  cmc_data = open(url)
  data = {}

  @doc = Nokogiri::HTML(cmc_data)
  @doc.css('.table tbody tr').each do |tr|
    tds = tr.css('td').map { |e| e.text.strip }

    date_key = Date.strptime(tds[0], '%b %d, %Y').strftime('%d-%m-%Y')
    data[date_key] = {
      price: tds[1].to_f,
      volume: convert_to_number(tds[5]),
      marketCap: convert_to_number(tds[6]),
      year: date_key.split('-').last
    }
  end

  data.each do |key, value|
    year = value[:year]
    p year
    p key
    p value
  end
end

def help
  puts <<-EOF
This script parses the local history and returns coin info on certain dates

List of commands:

  * run
  * dl - downloads the history
  * help - this text

Example usage:

  ./saturn.rb
  ./saturn.rb run
  ruby saturn.rb help

  EOF
end

if ARGV.empty?
  run_script
else
  case ARGV[0]
  when 'run'
    run_script
  when 'dl'
    download_history
  when 'fill_blanks'
    fill_blanks
  else
    help
  end
end
