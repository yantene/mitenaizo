require 'cgi'

module Mitenaizo
  class Brain
    MARKOV_ORDER = 2
    BEGIN_TOKENS = (1..MARKOV_ORDER).map { |o| "__MITENAIZO_BEGIN_#{o}__" }.freeze
    END_TOKENS = (1..MARKOV_ORDER).map { |o| "__MITENAIZO_END_#{o}__" }.freeze

    def initialize
      @redis = Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'])
    end

    def memorize(text, channel)
      [*BEGIN_TOKENS, *tokenize(text), *END_TOKENS].each_cons(3) do |*precs, word|
        save_word(channel, precs, word)
      end
    end

    def speech(channel, max_words = Float::INFINITY)
      sentence = BEGIN_TOKENS.dup

      1.upto(max_words + MARKOV_ORDER) do
        break if sentence.last(MARKOV_ORDER) == END_TOKENS

        word = load_word(channel, sentence.last(MARKOV_ORDER))
        return nil if word.nil?

        sentence << word
      end

      sentence[MARKOV_ORDER..-(MARKOV_ORDER + 1)].join
    end

    private

    def save_word(channel, precs, word)
      @redis.sadd(['brain', channel, *precs].join('/'), word)
    end

    def load_word(channel, precs)
      @redis.srandmember(['brain', channel, *precs].join('/'))
    end

    EMOJI_PATTERN = /:[^:;.,!?@#$%^&*(){}\[\]<>\/\\=\s]+:/.freeze

    def tokenize(text)
      emojis = []
      stripped = text.gsub(/(#{EMOJI_PATTERN}|@)/) { |emoji|
        emojis << emoji
        '@'
      }

      BimyouSegmenter.segment(stripped, white_space: true).flat_map { |token|
        token.split('@', -1).then { |tokens|
          tokens.zip(emojis.shift(tokens.size - 1)).flatten.compact.reject { |e| e == '' }
        }
      }
    end
  end
end
