# -*- coding: utf-8 -*- #
# frozen_string_literal: true

# See http://www.cs.cmu.edu/afs/andrew/course/15/411/ghc/share/doc/ghc/ext-core/core.pdf for a description of the syntax
# of the language and https://www.aosabook.org/en/ghc.html for a high level overview.
module Rouge
  module Lexers
    class GhcCore < RegexLexer
      title "GHC Core"
      desc "Intermediate representation of the GHC Haskell compiler."
      tag 'ghc-core'

      filenames '*.dump-simpl', '*.dump-cse', '*.dump-ds', '*.dump-spec'

      state :root do
        # sections
        rule %r/^====================[\w ]+====================$/, Generic::Heading
        # timestamps
        rule %r/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2}\.\d+ UTC$/, Comment::Single
        rule %r/^Result size of .+\s*.*}/, Comment::Multiline
        rule %r/--.*$/, Comment::Single

        rule %r/\[/, Comment::Special, :annotation

        mixin :recursive_binding
        mixin :ghc_rule
        mixin :function

        # rest is Text
        rule %r/\s/m, Text
        rule %r/.*/, Text
      end

      state :expression do
        rule %r/[\n]+/, Text
        rule %r/(?=^\S)/ do
          pop!
        end

        rule %r/\s+/, Text, :expression_line
      end

      state :expression_line do
        rule %r/ /, Text

        mixin :common

        rule %r/\n/, Text, :pop!
      end

      state :annotation do
        rule %r/\]/, Comment::Special, :pop!
        rule %r/\[/, Comment::Special, :annotation
        rule %r/[^\[\]]+/, Comment::Special
        rule %r/\s+/, Comment::Special
      end

      state :common do
        rule %r/\[/, Comment::Special, :annotation

        rule %r/\d+\#{0,2}/, Literal::Number::Integer

        mixin :constants
        mixin :punctuation
        mixin :operator
        mixin :name
      end

      state :constants do
        rule %r/__DEFAULT/, Name::Constant
      end

      state :name do
        rule %r/^([A-Z]\w*)(\.)/ do |m|
          token Name::Namespace, m[0]
          token Punctuation, m[1]
        end

        rule %r/[A-Z][^\s.,(){}]*/, Keyword::Type
        rule %r/\S[^\s.,(){}]*/, Name::Variable
      end

      state :punctuation do
        rule %r/[.,(){}]/, Punctuation
      end

      state :operator do
        rule %r/=>/, Operator
        rule %r/->/, Operator
        rule %r/::/, Operator
        rule %r/=/, Operator
        rule %r/forall/, Keyword
        rule %r/case/, Keyword
        rule %r/of/, Keyword
        rule %r/let/, Keyword
        rule %r/join/, Keyword
        rule %r/@/, Operator
        rule %r/\\/, Operator
      end

      state :recursive_binding do
        rule %r/(Rec)(\s*)({)/ do |m|
          token Keyword, m[1]
          token Text, m[2]
          token Punctuation, m[3]
        end

        rule %r/^(end)(\s*)(Rec)(\s*)(})/ do |m|
          token Keyword, m[1]
          token Text, m[2]
          token Keyword, m[3]
          token Text, m[4]
          token Punctuation, m[5]
        end
      end

      state :ghc_rule do
        rule %r/^(?<name>".*?")/m do |m|
          token Name::Label, m[:name]

          push :expression
        end
      end

      state :function do
        rule %r/^(?<name>\S+)(?=.*?(=|::))/m do |m|
          token Name::Function, m[:name]

          push :expression
        end
      end
    end
  end
end
