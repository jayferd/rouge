# -*- coding: utf-8 -*- #
# frozen_string_literal: true

module Rouge
  module Formatters
    # Transforms a token stream into HTML output.
    class HTML < Formatter
      tag 'html'

      # @yield the html output.
      def stream(tokens, &b)
        tokens.each { |tok, val| yield span(tok, val) }
      end

      def span(tok, val)
        return val if escape?(tok)

        safe_span(tok, escape_special_html_chars(val))
      end

      def safe_span(tok, safe_val)
        if tok == Token::Tokens::Text
          safe_val
        else
          shortname = tok.shortname \
            or raise "unknown token: #{tok.inspect} for #{safe_val.inspect}"

          "<span class=\"#{shortname}\">#{safe_val}</span>"
        end
      end

      TABLE_FOR_ESCAPE_HTML = {
        '&' => '&amp;',
        '<' => '&lt;',
        '>' => '&gt;',
      }

    private
      def escape_special_html_chars(value)
        escape_regex = /[&<>]/
        return value unless value =~ escape_regex

        value.gsub(escape_regex, TABLE_FOR_ESCAPE_HTML)
      end
    end
  end
end
