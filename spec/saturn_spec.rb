require 'spec_helper'

describe 'saturn.rb' do
  let(:v8) { 'public/api/v8' }
  let(:path) { "#{v8}/history/saturn.json" }
  let(:keys) { ['timestamp', 'timestampFriendly', 'currency', 'total',
                'active_currencies', 'active_assets', 'coins'].sort }
  let(:price_keys) { ['1day', '2day', '3day', '14day', '30day', '60day',
                      '90day', '120day', '150day', '180day', '365day'].sort }

  it 'exists' do
    expect(File.exist?(path)).to be true
  end

  it 'has all the keys' do
    expect(saturn.keys.sort).to eq keys
  end

  it 'has the correct types' do
    expect(saturn['timestamp']).to be_a Integer
    expect(saturn['timestampFriendly']).to be_a String
    expect(saturn['currency']).to be_a String
    expect(saturn['total']).to be_a Integer
    expect(saturn['active_assets']).to be_a Integer
    expect(saturn['active_currencies']).to be_a Integer
    expect(saturn['coins']).to be_a Hash
  end

  it 'has bitcoin nested in coins' do
    expect(saturn['coins']['bitcoin']).to be_a Hash
    expect(saturn['coins']['bitcoin']['name']).to eq 'Bitcoin'
    expect(saturn['coins']['bitcoin']['symbol']).to eq 'BTC'
    expect(saturn['coins']['bitcoin']['identifier']).to eq 'bitcoin'
    expect(saturn['coins']['bitcoin']['category']).to eq 'currency'
    expect(saturn['coins']['bitcoin']['price']).to be_a Hash
    expect(saturn['coins']['bitcoin']['price'].keys.sort).to eq price_keys
  end
end
