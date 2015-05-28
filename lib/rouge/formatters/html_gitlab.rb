require 'cgi'

module Rouge
  module Formatters
    class HTMLGitlab < Formatter
      tag 'html_gitlab'

      # Creates a new <tt>Rouge::Formatter::HTMLGitlab</tt> instance.
      #
      # [+nowrap+]          If set to True, don't wrap the output at all, not
      #                     even inside a <tt><pre></tt> tag (default: false).
      # [+cssclass+]        CSS class for the wrapping <tt><div></tt> tag
      #                     (default: 'highlight').
      # [+linenos+]         If set to 'table', output line numbers as a table
      #                     with two cells, one containing the line numbers,
      #                     the other the whole code. This is copy paste friendly,
      #                     but may cause alignment problems with some browsers
      #                     or fonts. If set to 'inline', the line numbers will
      #                     be integrated in the <tt><pre></tt> tag that contains
      #                     the code (default: nil).
      # [+linenostart+]     The line number for the first line (default: 1).
      # [+lineanchors+]     If set to true the formatter will wrap each output
      #                     line in an anchor tag with a name of L-linenumber.
      #                     This allows easy linking to certain lines
      #                     (default: false).
      # [+lineanchorsid+]   If lineanchors is true the name of the anchors can
      #                     be changed with lineanchorsid to e.g. foo-linenumber
      #                     (default: 'L').
      # [+anchorlinenos+]   If set to true, will wrap line numbers in <tt><a></tt>
      #                     tags. Used in combination with linenos and lineanchors
      #                     (default: false).
      # [+inline_theme+]    Inline CSS styles for the <pre> tag (default: false).
      def initialize(
          nowrap: false,
          cssclass: 'highlight',
          linenos: nil,
          linenostart: 1,
          lineanchors: false,
          lineanchorsid: 'L',
          anchorlinenos: false,
          inline_theme: nil
        )
        @nowrap = nowrap
        @cssclass = cssclass
        @linenos = linenos
        @linenostart = linenostart
        @lineanchors = lineanchors
        @lineanchorsid = lineanchorsid
        @anchorlinenos = anchorlinenos
        @inline_theme = inline_theme
      end

      def render(tokens)
        case @linenos
        when 'table'
          render_tableized(tokens)
        when 'inline'
          render_untableized(tokens)
        else
          render_untableized(tokens)
        end
      end

      alias_method :format, :render

      private

      def render_untableized(tokens)
        data = process_tokens(tokens)

        html = ''
        html << "<pre class=\"#{@cssclass}\"><code>" unless @nowrap
        html << wrap_lines(data[:code])
        html << "</code></pre>\n" unless @nowrap
      end

      def render_tableized(tokens)
        data = process_tokens(tokens)

        html = ''
        html << "<div class=\"#{@cssclass}\">" unless @nowrap
        html << '<table><tbody>'
        html << "<td class=\"linenos\"><pre>"
        html << wrap_linenos(data[:numbers])
        html << '</pre></td>'
        html << "<td class=\"lines\"><pre><code>"
        html << wrap_lines(data[:code])
        html << '</code></pre></td>'
        html << '</tbody></table>'
        html << '</div>' unless @nowrap
      end

      def process_tokens(tokens)
        num_lines = 0
        last_val = ''
        rendered = ''

        tokens.each do |tok, val|
          last_val = val
          num_lines += val.scan(/\n/).size
          rendered << span(tok, val)
        end

        numbers = (@linenostart..num_lines + @linenostart - 1).to_a

        { numbers: numbers, code: rendered }
      end

      def wrap_linenos(numbers)
        if @anchorlinenos
          numbers.map! do |number|
            "<a href=\"##{@lineanchorsid}#{number}\">#{number}</a>"
          end
        end
        numbers.join("\n")
      end

      def wrap_lines(rendered)
        if @lineanchors
          lines = rendered.split("\n")
          lines = lines.each_with_index.map do |line, index|
            number = index + @linenostart

            if @linenos == 'inline'
              "<a name=\"L#{number}\"></a>" \
              "<span class=\"linenos\">#{number}</span>" \
              "<span id=\"#{@lineanchorsid}#{number}\" class=\"line\">#{line}" \
              '</span>'
            else
              "<span id=\"#{@lineanchorsid}#{number}\" class=\"line\">#{line}" \
              '</span>'
            end
          end
          lines.join("\n")
        else
          if @linenos == 'inline'
            lines = rendered.split("\n")
            lines = lines.each_with_index.map do |line, index|
              number = index + @linenostart
              "<span class=\"linenos\">#{number}</span>#{line}"
            end
            lines.join("\n")
          else
            rendered
          end
        end
      end

      def span(tok, val)
        # http://stackoverflow.com/a/1600584/2587286
        val = CGI.escapeHTML(val)

        if tok.shortname.empty?
          val
        else
          if @inline_theme
            theme = Theme.find(@inline_theme).new
            rules = theme.style_for(tok).rendered_rules
            "<span style=\"#{rules.to_a.join(';')}\">#{val}</span>"
          else
            "<span class=\"#{tok.shortname}\">#{val}</span>"
          end
        end
      end
    end
  end
end
