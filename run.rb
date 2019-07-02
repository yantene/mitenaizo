#!/usr/bin/env ruby

require 'bundler'
Bundler.require
require_relative './src/mitenaizo/bot'

bot = Mitenaizo::Bot.new

bot.start!
