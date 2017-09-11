#!/usr/bin/env bash

source ~/.rvm/environments/ruby-2.1.0@coinmarketcap
ruby ~/coinmarketcap.northpole.ro/current/saturn.rb > ~/coinmarketcap.northpole.ro/current/logs/cron-saturn.log 2>&1
