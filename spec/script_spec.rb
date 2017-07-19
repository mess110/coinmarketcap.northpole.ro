require 'spec_helper'

describe 'script' do
  before :all do
    require './script.rb'
    @doc = Nokogiri::HTML(open("http://coinmarketcap.com/all/views/all/"))
    @ts = Time.now.to_i
    @json = get_json_data('#currencies-all')
  end

  it 'has a timestamp' do
    expect(@json['timestamp']).to eq @ts
  end

  it 'returns the markets' do
    expect(@json['markets'].class).to be Array
  end

  it 'contains global data' do
    expect(@json['global']).to_not be_nil
  end

  it 'knows the world is not broken and people are not crying' do
    expect(@json['markets'].last['symbol']).to eq 'BTC'
  end
end
