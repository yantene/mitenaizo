require_relative './brain'

module Mitenaizo
  class Bot
    IGNORE_PATTERN = /[<>]/.freeze

    def initialize
      Slack.configure do |config|
        config.token = ENV['HUBOT_SLACK_TOKEN']
      end
      @client = Slack::RealTime::Client.new

      @brain = Mitenaizo::Brain.new

      @client.on :message do |data|
        next unless data['type'] == 'message' && data['subtype'].nil?
        next unless data['bot_id'].nil?

        STDERR.puts(data.inspect)
        case data.text
        when /<@#{@client.self.id}>/
          when_receive_mention(data)
        when IGNORE_PATTERN
          # When include anti-pattern
        else
          when_receive_monologue(data)
        end
      end
    end

    def start!
      @client.start!
    end

    private

    def when_receive_mention(data)
      STDERR.puts("[#{data.channel}] receive mention: #{CGI.unescapeHTML(data.text)}")
      text = @brain.speech(data.channel, 100)
      @client.message(
        {
          channel: data.channel,
          text: "<@#{data.user}> #{text}",
          as_user: true
        }.tap { |hash|
          break hash.merge(thread_ts: data['thread_ts']) if data['thread_ts']
        }
      )
      STDERR.puts("[#{data.channel}] post: #{text}")
    end

    def when_receive_monologue(data)
      STDERR.puts("[#{data.channel}] receive monologue: #{CGI.unescapeHTML(data.text)}")
      @brain.memorize(CGI.unescapeHTML(data.text), data.channel)
    end
  end
end
