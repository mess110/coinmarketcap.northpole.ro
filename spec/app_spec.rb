require 'spec_helper'

describe 'live_test', live: true do
  let(:base_url) { 'https://coinmarketcap.northpole.ro' }

  describe 'protocol' do
    describe 'http' do
      subject { json_req('http://coinmarketcap.northpole.ro/api/v8/bitcoin.json') }
      it { is_expected.to be_updated_within(20) }
    end

    describe 'https' do
      subject { json_req("#{base_url}/api/v8/bitcoin.json") }
      it { is_expected.to be_updated_within(20) }
    end
  end

  describe 'coins.json' do
    subject { json_req("#{base_url}/coins.json") }
    it { is_expected.to have_key('coins') }
  end

  describe 'ticker.json' do
    subject { json_req("#{base_url}/ticker.json") }
    it { is_expected.to be_updated_within(20) }
  end

  describe 'history.json' do
    subject { json_req("#{base_url}/history.json?coin=bitcoin") }
    it { is_expected.to have_key('history') }
  end

  describe 'saturn.json updates' do
    subject { json_req("#{base_url}/saturn.json") }
    it { is_expected.to be_updated_within(60 * 24) }
    it { is_expected.to have_key('coins') }
  end
end
