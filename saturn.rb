#!/usr/bin/env ruby

# this scripts should take you to the Moon, but if you miss, it will take you
# to Saturn

require 'json'

DAY = 60 * 60 * 24

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
end

def run_script
  timestamp = Time.now.to_i
  puts "Starting script at #{Time.at(timestamp)}"

  current_folder = File.dirname(File.expand_path(__FILE__))
  base_path = File.join(current_folder, 'public/api/v8/history/')
  output_path = File.join(current_folder, 'saturn.json')

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
    coins: {}
  }

  coins.each do |coin|
    all_history = read(coin)

    # TODO: what if no history
    meta = all_history['history'].values.last

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
  timestamp = Time.now.to_i
  puts "Starting script at #{Time.at(timestamp)}"

  puts 'TODO: not implemented'

  now = Time.now
  puts "Script finished at #{now}. (#{(now - timestamp).to_i} seconds)"
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
  else
    help
  end
end
