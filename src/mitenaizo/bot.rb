require_relative './brain'

module Mitenaizo
  class Bot
    ENTITY_PATTERN = /<[^\s>]+>/.freeze

    def initialize
      Slack.configure do |config|
        config.token = ENV['HUBOT_SLACK_TOKEN']
      end
      @client = Slack::RealTime::Client.new

      @brain = Mitenaizo::Brain.new

      @client.on :message do |data|
        next unless data['type'] == 'message' && data['subtype'].nil?
        # next unless data['bot_id'].nil?

        STDERR.puts(data.inspect)

        when_receive_mention(data) if data.text =~ /<@#{@client.self.id}>/

        when_receive(data)
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

    def when_receive(data)
      text = CGI.unescapeHTML(data.text.gsub(ENTITY_PATTERN, '')).strip
      STDERR.puts("[#{data.channel}] receive post: #{text}")
      @brain.memorize(text, data.channel)
    end
  end
end
