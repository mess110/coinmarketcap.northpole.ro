Install
=======

# Setup

rvm install 2.1.0

git clone git@github.com:mess110/coinmarketcap.northpole.ro.git coinmarketcap-api

cd coinmarketcap-api

bundle install

ruby script.rb

# Deploy with capistrano

cap production deploy # This will run the generate:doc rake task

# Load the crontab

crontab crons/northpole-crontab
