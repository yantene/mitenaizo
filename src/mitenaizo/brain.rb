require 'cgi'

module Mitenaizo
  class Brain
    MARKOV_ORDER = 2
    BEGIN_TOKENS = (1..MARKOV_ORDER).map { |o| "__MITENAIZO_BEGIN_#{o}__" }.freeze
    END_TOKENS = (1..MARKOV_ORDER).map { |o| "__MITENAIZO_END_#{o}__" }.freeze

    MAX_WORDS = 100

    def initialize
      @redis = Redis.new(host: ENV['REDIS_HOST'], port: ENV['REDIS_PORT'])
    end

    # channel のデータとして text を記憶する
    def memorize(text, channel)
      [*BEGIN_TOKENS, *tokenize(text), *END_TOKENS].each_cons(3) do |*precs, word|
        save_word(channel, precs, word)
      end
    end

    # channel で記憶したデータから文を生成する
    def speech(channel)
      loop do
        generate_sentence(channel).tap do |sentence|
          return sentence
        end
      end
    end

    private

    # channel で記憶したデータから文を生成する
    def generate_sentence(channel)
      sentence = BEGIN_TOKENS.dup

      1.upto(MAX_WORDS + MARKOV_ORDER) do
        break if sentence.last(MARKOV_ORDER) == END_TOKENS

        word = load_word(channel, sentence.last(MARKOV_ORDER))
        return nil if word.nil?

        sentence << word
      end

      sentence[MARKOV_ORDER..-(MARKOV_ORDER + 1)].join
    end

    # channel で記憶したデータへ、 precs に続く単語を word として記憶する
    def save_word(channel, precs, word)
      @redis.sadd(['brain', channel, *precs].join('/'), word)
    end

    # channel で記憶したデータから、 precs に続く単語を返す
    def load_word(channel, precs)
      @redis.srandmember(['brain', channel, *precs].join('/'))
    end

    # Slack の emoji shortcode にマッチする正規表現
    EMOJI_PATTERN = /:[^:;.,!?@#$%^&*(){}\[\]<>\/\\=\s]+:/.freeze

    # text を分かち書きする
    def tokenize(text)
      # text 中の絵文字と "@" を一旦 "@" に置換し、 emojis に退避しておく。
      emojis = []
      stripped = text.gsub(/(#{EMOJI_PATTERN}|@)/) { |emoji|
        emojis << emoji
        '@'
      }

      # 分かち書きした後、@ からなるトークンを emojis に退避した文字列に戻す。
      # また、@ を部分文字列として含むトークンは、
      # @ を emojis に退避した文字列に戻した上で、その前後を別トークンとして扱う。
      BimyouSegmenter.segment(stripped, white_space: true).flat_map { |token|
        token.split('@', -1).then { |tokens|
          tokens.zip(emojis.shift(tokens.size - 1)).flatten.compact.reject(&:empty?)
        }
      }
    end
  end
end
