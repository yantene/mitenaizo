module Mitenaizo
  module Validator
    # 全バリデーションを実行
    def self.validate(text)
      (singleton_methods - :validate).all? { |method| call(method, text) }
    end

    PARENTHESES = '<>＜＞()（）{}｛｝[]［］「」『』【】'.chars.freeze
    PARENTHESES_OPEN, PARENTHESES_CLOSE = PARENTHESES.each_slice(2).to_a.transpose.map(&:freeze)
    PARENTHESES_MAP = PARENTHESES_OPEN.zip(PARENTHESES_CLOSE).to_h.freeze

    # text 中で括弧の対応が取れていれば true、そうでなければ false を返す。
    def self.parentheses(text)
      stack = []
      text.each_char do |char|
        case char
        when *PARENTHESES_OPEN
          stack.push(char)
        when *PARENTHESES_CLOSE
          return false unless PARENTHESES_MAP[stack.pop] == char
        end
      end
      return false unless stack.empty?

      true
    end

    # 中身が空なら true、そうでなければ false を返す。
    def self.present(text)
      !text.blank?
    end
  end
end
