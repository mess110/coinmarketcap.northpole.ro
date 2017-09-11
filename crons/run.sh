#!/usr/bin/env bash

source ~/.rvm/environments/ruby-2.1.0@coinmarketcap
ruby ~/coinmarketcap.northpole.ro/current/script.rb > ~/coinmarketcap.northpole.ro/current/logs/cron-script.log 2>&1
