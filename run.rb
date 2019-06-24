#!/usr/bin/env ruby

require 'bundler'
Bundler.require
require_relative './src/mitenaizo/bot'

Dotenv.load

bot = Mitenaizo::Bot.new

bot.start!
