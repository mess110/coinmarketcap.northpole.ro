#!/usr/bin/env bash

source ~/.rvm/environments/ruby-2.4.3@coinmarketcap.2.4.3
ruby ~/coinmarketcap.northpole.ro/current/script.rb > ~/coinmarketcap.northpole.ro/current/logs/cron-script.log 2>&1
