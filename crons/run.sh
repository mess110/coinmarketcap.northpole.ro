#!/usr/bin/env bash

BASEDIR=$(dirname $0)
source ~/.rvm/environments/ruby-2.1.0@coinmarketcap
ruby ~/coinmarketcap.northpole.ro/current/script.rb > ~/coinmarketcap.northpole.ro/current/script.log 2>&1
