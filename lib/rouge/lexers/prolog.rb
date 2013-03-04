module Rouge
  module Lexers
    class Prolog < RegexLexer
      desc "The Prolog programming language (http://en.wikipedia.org/wiki/Prolog)"
      tag 'prolog'
      aliases 'prolog'
      filenames '*.pro', '*.P', '*.prolog'
      mimetypes 'text/x-prolog'

      def self.analyze_text(text)
        return 1 if text =~ /\A\w+(\(\w+\,\s*\w+\))*\./
      end

      state :basic do
        rule /\s+/, 'Text'
        rule /^#.*/, 'Comment.Single'
        rule /\/\*/, 'Comment.Multiline', :nested_comment

        rule /[\[\](){}|.,;!]/, 'Punctuation'
        rule /:-|-->/, 'Punctuation'

        rule /"[^"]*"/, 'Literal.String.Double'

        rule /\d+\.\d+/, 'Literal.Number.Float'
        rule /\d+/, 'Literal.Number'
      end

      state :atoms do
        rule /[[:lower:]]+(_|[[:lower]]|[[:digit:]])*/, 'Literal.String.Atom'
        rule /'[^']*'/, 'Literal.String.Atom'
      end

      state :operators do
        rule /(<|>|=<|>=|==|=:=|=|\/|\/\/|\*|\+|-)(?=\s|[a-zA-Z0-9\[])/,
          'Operator'
        rule /is/, 'Operator'
        rule /(mod|div|not)/, 'Operator'
        rule /[#&*+-.\/:<=>?@^~]+/, 'Operator'
      end

      state :variables do
        rule /[A-Z]+\S*/, 'Name.Variable'
        rule /_[[:word:]]*/, 'Name.Variable'
      end

      state :root do
        mixin :basic
        mixin :atoms
        mixin :variables
        mixin :operators
      end

      state :nested_comment do
        rule /\/\*/, 'Comment.Multiline', :push
        rule /\s*\*[^*\/]+/, 'Comment.Multiline'
        rule /\*\//, 'Comment.Multiline', :pop!
      end
    end
  end
end
