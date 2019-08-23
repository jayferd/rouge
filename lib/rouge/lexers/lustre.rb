# -*- coding: utf-8 -*- #
#
# adapted from ocaml.rb, hence some ocaml-ism migth remains
module Rouge
  module Lexers
    class Lustre < RegexLexer
      title "Lustre"
      desc 'The Lustre programming language (Verimag)'
      tag 'lustre'
      filenames '*.lus'
      mimetypes 'text/x-lustre'

      def self.keywords
        @keywords ||= Set.new %w(
          extern unsafe assert const current enum function
          let node operator returns
          step struct tel type var  model package needs
          provides uses is body end include merge
        )
      end

      def self.word_operators
        @word_operators ||= Set.new %w(
           div and xor mod or not nor if then else fby pre when with) 
      end

      def self.primitives
        @primitives ||= Set.new %w(int real bool)
      end

      operator = %r([,!$%&*+./:<=>?@^|~#-]+)
      id = /[a-z_][\w']*/i

      state :root do
        rule (/\s+/m), Text
        rule (/false|true/), Keyword::Constant
        rule %r(\-\-.*), Comment::Single
        rule %r(/\*.*?\*/)m, Comment::Multiline
        rule %r(\(\*.*?\*\))m, Comment::Multiline
        rule id do |m|
          match = m[0]
          if self.class.keywords.include? match
            token Keyword
          elsif self.class.word_operators.include? match
            token Operator::Word
          elsif self.class.primitives.include? match
            token Keyword::Type
          else
            token Name
          end
        end

        rule (/[(){}\[\];]+/), Punctuation
        rule operator, Operator

        rule (/-?\d[\d_]*(.[\d_]*)?(e[+-]?\d[\d_]*)/i), Num::Float
        rule (/\d[\d_]*/), Num::Integer

        rule (/'(?:(\\[\\"'ntbr ])|(\\[0-9]{3})|(\\x\h{2}))'/), Str::Char
        rule (/'[.]'/), Str::Char
        rule (/"/), Str::Double, :string
        rule (/[~?]#{id}/), Name::Variable
      end

      state :string do
        rule (/[^\\"]+/), Str::Double
        mixin :escape_sequence
        rule (/\\\n/), Str::Double
        rule (/"/), Str::Double, :pop!
      end

      state :escape_sequence do
        rule (/\\[\\"'ntbr]/), Str::Escape
        rule (/\\\d{3}/), Str::Escape
        rule (/\\x\h{2}/), Str::Escape
      end

    end
  end
end
