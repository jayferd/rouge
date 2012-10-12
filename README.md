# Rouge

This project needs your help!  There are lots of lexers to be implemented / ported / fixed, and features that need to be added or implemented.  If you'd like to help out, assign yourself something from the [issues][] page, and send me a pull request (even if it's not done yet!).  Bonus points for feature branches.

[issues]: /jayferd/rouge/issues

## Usage

First, take a look at the [pretty colors][].

[pretty colors]: http://jayferd.us/posts/2012-09-14-rouge

``` ruby
# make some nice lexed html, compatible with pygments stylesheets
source = File.read('/etc/bashrc')
formatter = Rouge::Formatters::HTML.new(:css_class => '.highlight')
lexer = Rouge::Lexers::Shell.new
formatter.render(lexer.lex(source))

# Get some CSS
Rouge::Themes::ThankfulEyes.render(:scope => '.highlight')
```

Rouge aims to be simple to extend, and to be a drop-in replacement pygments, with the same quality of output.

### Advantages to pygments.rb
* No python bridge is necessary - you can deploy it on Heroku effortlessly, without the need for [epic hacks][].
[epic hacks]: https://github.com/rumblelabs/pygments-heroku

### Advantages to CodeRay
* The HTML output from Rouge is fully compatible with stylesheets designed for pygments.
* The lexers are implemented with a dedicated DSL, rather than being hand-coded.

## You can even use it with Redcarpet

``` ruby
require 'rouge/plugins/redcarpet'
class HTML < Redcarpet::Render::HTML
  include Rouge::Plugins::Redcarpet # yep, that's it.
end
```

If you have `:fenced_code_blocks` enabled, you can specify languages, and even options with CGI syntax, like `php?start_inline=1`, or `erb?parent=javascript`.

## Encodings

Rouge is only for UTF-8 strings.  If you'd like to highlight a string with a different encoding, please convert it to UTF-8 first.

## Contributing

### Run the tests

You can test the core of Rouge simply by running `rake` (no `bundle exec` required).  It's also set up with `guard`, if you like.

To test a lexer visually, run `rackup` from the root and go to `localhost:9292/#{some_lexer}` where `some_lexer` is the tag or an alias of a lexer you'd like to test.

### Using the lexer DSL

You can probably learn a lot just by reading through the existing lexers.  Basically, a lexer consists of a collection of states, each of which has several rules.  A rule consists of a regular expression and an action, which yields tokens and manipulates the state stack.  Each rule in the state on top of the stack is tried *in order* until a match is found, at which point the action is run, the match consumed from the stream, and the process repeated with the new lexer on the top of the stack.  Each lexer has a special state called `:root`, and the initial state stack consists of just this state.

Here's how you might use it:

``` ruby
class MyLexer < Rouge::RegexLexer
  state :root do
    # the "easy way"
    rule /abc/, 'A.Token'
    rule /abc/, 'A.Token', :next_state
    rule /abc/, 'A.Token', :pop!

    # the "flexible way"
    rule /abc/ do |m|
      # m is the match, for accessing match groups manually

      # you can do the following things:
      pop!
      push :another_state
      push # assumed to be the current state
      state? :some_state # check if the current state is :some_state
      in_state? :some_state # check if :some_state is in the state stack

      eos? # check if the stream is empty

      # yield a token.  if no second argument is supplied, the value is
      # taken to be the whole match.
      # The sum of all the tokens yielded must be equivalent to the whole
      # match - otherwise characters will go missing from the user's input.
      token 'A.Token.Type', m[0]

      # calls SomeOtherLexer.lex(str) and yields its output.  See the
      # HTML lexer for a nice example of this.
      # if no second argument is supplied, it is assumed to be the whole
      # match string.
      delegate SomeOtherLexer, str

      # the context object is the lexer itself, so you can stash state here
      @count ||= 0
      @count += 1

      # advanced: push a dynamically created anonymous state
      push do
        rule /.../, 'A.Token'
      end
    end

    rule /(a)(b)/ do
      # "group" yields the matched groups in order
      group 'Letter.A'
      group 'Letter.B'
    end
  end

  start do
    # this is run whenever a fresh lex is started
  end
end
```
