# -*- coding: utf-8 -*- #
# frozen_string_literal: true

# not required by the main lib.
# to use this module, require 'rouge/cli'.

require 'rbconfig'

module Rouge
  class FileReader
    attr_reader :input
    def initialize(input)
      @input = input
    end

    def file
      case input
      when '-'
        IO.new($stdin.fileno, 'rt:bom|utf-8')
      when String
        File.new(input, 'rt:bom|utf-8')
      when ->(i){ i.respond_to? :read }
        input
      end
    end

    def read
      @read ||= begin
        file.read
      rescue => e
        $stderr.puts "unable to open #{input}: #{e.message}"
        exit 1
      ensure
        file.close
      end
    end
  end

  class CLI
    LOADED_FILES = Set.new
    LOADED_CONSTANTS = Set.new

    def self.doc
      return enum_for(:doc) unless block_given?

      yield %|usage: rougify {global options} [command] [args...]|
      yield %||
      yield %|where <command> is one of:|
      yield %|	highlight	#{Highlight.desc}|
      yield %|	debug		#{Debug.desc}|
      yield %|	help		#{Help.desc}|
      yield %|	style		#{Style.desc}|
      yield %|	list		#{List.desc}|
      yield %|	guess		#{Guess.desc}|
      yield %|	server		#{Server.desc}|
      yield %|	version		#{Version.desc}|
      yield %||
      yield %|and global options include:|
      yield %[	--require|-r <fname>	require <fname> after loading rouge]
      yield %||
      yield %|See `rougify help <command>` for more info.|
    end

    class Error < StandardError
      attr_reader :message, :status
      def initialize(message, status=1)
        @message = message
        @status = status
      end
    end

    def self.parse(argv=ARGV)
      argv = normalize_syntax(argv)

      until argv.empty?
        head = argv.shift

        case head
        when '-h', '--help', 'help', '-help'
          return Help.parse(argv)
        when '--require', '-r'
          require_file argv.shift
        else
          break
        end
      end

      klass = class_from_arg(head)
      return klass.parse(argv) if klass

      argv.unshift(head) if head
      Highlight.parse(argv)
    end

    def self.require_file(file)
      error!("please specify a filename after -r|--require") if file.nil? || file.empty?

      toplevel = Object.constants
      require file
      new_constants = Set.new(Object.constants) - toplevel
      LOADED_CONSTANTS.merge(new_constants)
      LOADED_FILES << file
    end

    def initialize(options={})
    end

    def self.error!(msg, status=1)
      raise Error.new(msg, status)
    end

    def error!(*a)
      self.class.error!(*a)
    end

    def self.class_from_arg(arg)
      case arg
      when 'version', '--version', '-v' then Version
      when 'help', nil then Help
      when 'highlight', 'hi' then Highlight
      when 'debug' then Debug
      when 'style' then Style
      when 'list' then List
      when 'guess' then Guess
      when 'server' then Server
      end
    end

    class Version < CLI
      def self.desc
        "print the rouge version number"
      end

      def self.parse(*); new; end

      def run
        puts Rouge.version
      end
    end

    class Help < CLI
      def self.desc
        "print help info"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %|usage: rougify help <command>|
        yield %||
        yield %|print help info for <command>.|
      end

      def self.parse(argv)
        opts = { :mode => CLI }
        until argv.empty?
          arg = argv.shift
          klass = class_from_arg(arg)
          if klass
            opts[:mode] = klass
            next
          end
        end
        new(opts)
      end

      def initialize(opts={})
        @mode = opts[:mode]
      end

      def run
        @mode.doc.each(&method(:puts))
      end
    end

    class Highlight < CLI
      def self.desc
        "highlight code"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %[usage: rougify highlight <filename> [options...]]
        yield %[       rougify highlight [options...]]
        yield %[]
        yield %[--input-file|-i <filename>  specify a file to read, or - to use stdin]
        yield %[]
        yield %[--lexer|-l <lexer>          specify the lexer to use.]
        yield %[                            If not provided, rougify will try to guess]
        yield %[                            based on --mimetype, the filename, and the]
        yield %[                            file contents.]
        yield %[]
        yield %[--formatter|-f <opts>       specify the output formatter to use.]
        yield %[                            If not provided, rougify will default to]
        yield %[                            terminal256.]
        yield %[]
        yield %[--theme|-t <theme>          specify the theme to use for highlighting]
        yield %[                            the file. (only applies to some formatters)]
        yield %[]
        yield %[--mimetype|-m <mimetype>    specify a mimetype for lexer guessing]
        yield %[]
        yield %[--lexer-opts|-L <opts>      specify lexer options in CGI format]
        yield %[                            (opt1=val1&opt2=val2)]
        yield %[]
        yield %[--formatter-opts|-F <opts>  specify formatter options in CGI format]
        yield %[                            (opt1=val1&opt2=val2)]
        yield %[]
        yield %[--require|-r <filename>     require a filename or library before]
        yield %[                            highlighting]
        yield %[]
        yield %[--escape                    allow the use of escapes between <! and !>]
        yield %[]
        yield %[--escape-with <l> <r>       allow the use of escapes between custom]
        yield %[                            delimiters. implies --escape]
      end

      # There is no consistent way to do this, but this is used elsewhere,
      # and we provide explicit opt-in and opt-out with $COLORTERM
      def self.supports_truecolor?
        return true if %w(24bit truecolor).include?(ENV['COLORTERM'])
        return false if ENV['COLORTERM'] && ENV['COLORTERM'] =~ /256/

        if RbConfig::CONFIG['host_os'] =~ /mswin|mingw/
          ENV['ConEmuANSI'] == 'ON' && !ENV['ANSICON']
        else
          ENV['TERM'] !~ /(^rxvt)|(-color$)/
        end
      end

      def self.parse_opts(argv)
        opts = {
          :formatter => supports_truecolor? ? 'terminal-truecolor' : 'terminal256',
          :theme => 'thankful_eyes',
          :css_class => 'codehilite',
          :input_file => '-',
          :lexer_opts => {},
          :formatter_opts => {},
          :requires => [],
        }

        until argv.empty?
          arg = argv.shift
          case arg
          when '-r', '--require'
            opts[:requires] << argv.shift
          when '--input-file', '-i'
            opts[:input_file] = argv.shift
          when '--mimetype', '-m'
            opts[:mimetype] = argv.shift
          when '--lexer', '-l'
            opts[:lexer] = argv.shift
          when '--formatter-preset', '-f'
            opts[:formatter] = argv.shift
          when '--theme', '-t'
            opts[:theme] = argv.shift
          when '--css-class', '-c'
            opts[:css_class] = argv.shift
          when '--lexer-opts', '-L'
            opts[:lexer_opts] = parse_cgi(argv.shift)
          when '--escape'
            opts[:escape] = ['<!', '!>']
          when '--escape-with'
            opts[:escape] = [argv.shift, argv.shift]
          when /^--/
            error! "unknown option #{arg.inspect}"
          else
            opts[:input_file] = arg
          end
        end

        opts
      end

      def self.parse(argv)
        new(parse_opts(argv))
      end

      def input_stream
        @input_stream ||= FileReader.new(@input_file)
      end

      def input
        @input ||= input_stream.read
      end

      def lexer_class
        @lexer_class ||= Lexer.guess(
          :filename => @input_file,
          :mimetype => @mimetype,
          :source => input_stream,
        )
      end

      def raw_lexer
        lexer_class.new(@lexer_opts)
      end

      def escape_lexer
        Rouge::Lexers::Escape.new(
          start: @escape[0],
          end: @escape[1],
          lang: raw_lexer,
        )
      end

      def lexer
        @lexer ||= @escape ? escape_lexer : raw_lexer
      end

      attr_reader :input_file, :lexer_name, :mimetype, :formatter, :escape

      def initialize(opts={})
        Rouge::Lexer.enable_debug!

        opts[:requires].each do |r|
          require r
        end

        @input_file = opts[:input_file]

        if opts[:lexer]
          @lexer_class = Lexer.find(opts[:lexer]) \
            or error! "unknown lexer #{opts[:lexer].inspect}"
        else
          @lexer_name = opts[:lexer]
          @mimetype = opts[:mimetype]
        end

        @lexer_opts = opts[:lexer_opts]

        theme = Theme.find(opts[:theme]).new or error! "unknown theme #{opts[:theme]}"

        # TODO: document this in --help
        @formatter = case opts[:formatter]
        when 'terminal256' then Formatters::Terminal256.new(theme)
        when 'terminal-truecolor' then Formatters::TerminalTruecolor.new(theme)
        when 'html' then Formatters::HTML.new
        when 'html-pygments' then Formatters::HTMLPygments.new(Formatters::HTML.new, opts[:css_class])
        when 'html-inline' then Formatters::HTMLInline.new(theme)
        when 'html-line-table' then Formatters::HTMLLineTable.new(Formatters::HTML.new)
        when 'html-table' then Formatters::HTMLTable.new(Formatters::HTML.new)
        when 'null', 'raw', 'tokens' then Formatters::Null.new
        when 'tex' then Formatters::Tex.new
        else
          error! "unknown formatter preset #{opts[:formatter]}"
        end

        @escape = opts[:escape]
      end

      def run
        Formatter.enable_escape! if @escape
        formatter.format(lexer.lex(input), &method(:print))
      end

    private_class_method
      def self.parse_cgi(str)
        pairs = CGI.parse(str).map { |k, v| [k.to_sym, v.first] }
        Hash[pairs]
      end
    end

    class Debug < Highlight
      def self.desc
        "highlight code with debug features"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %|usage: rougify debug [<options>]|
        yield %||
        yield %|Debug a lexer. Similar options to `rougify highlight`, but|
        yield %|defaults to the `null` formatter, and ensures the `debug`|
        yield %|option is enabled, to print debugging information to stdout.|
      end

      def self.parse_opts(argv)
        out = super(argv)
        out[:lexer_opts]['debug'] = '1'
        out[:formatter] = 'null'

        out
      end
    end

    class Server < CLI
      def self.desc
        "run a server to view stress-test files"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %|usage: rougify server [<options>]|
        yield %||
        yield %|Run a development server which can test various lexers'|
        yield %|behavior on the included demo and stress-test files.|
        yield %||
        yield %|Visit / to see all the supported languages and their demos,|
        yield %|and visit /<lexer-name> (e.g. /ruby) to view a specific|
        yield %|lexer's stress-test file.|
        yield %||
        yield %|options:|
        yield %[  --port|-p <port>	Specify the port. Default:9292]
      end

      def self.parse(argv)
        opts = { debug: nil, port: '9292' }
        while argv.any?
          head = argv.shift
          case head
          when '-p', '--port' then opts[:port] = argv.shift \
                or error!("please provide a port after -p|--port")
          end
        end

        error!("invalid port `#{opts[:port]}'") unless opts[:port] =~ /\d+/

        new(opts)
      end

      def initialize(opts)
        @port = opts[:port].to_i
      end

      def run
        begin
          require 'rack'
          require 'sinatra'
        rescue LoadError
          puts %|Could not load rack or sinatra: these are development|
          puts %|dependencies required for running `rougify server`. Please|
          puts %|use `gem install --development rouge` or add sinatra to your|
          puts %|Gemfile.|
          exit 1
        end

        Kernel::load File.join(LIB_DIR, '../spec/visual/app.rb')
        VisualTestApp::RELOADABLE_CONSTANTS.merge(LOADED_CONSTANTS)
        VisualTestApp::RELOADABLE_FILES.merge(LOADED_FILES)

        Rack::Server.start app: VisualTestApp, Port: @port
      end
    end

    class Style < CLI
      def self.desc
        "print CSS styles"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %|usage: rougify style [<theme-name>] [<options>]|
        yield %||
        yield %|Print CSS styles for the given theme.  Extra options are|
        yield %|passed to the theme. To select a mode (light/dark) for the|
        yield %|theme, append '.light' or '.dark' to the <theme-name>|
        yield %|respectively. Theme defaults to thankful_eyes.|
        yield %||
        yield %|options:|
        yield %|  --scope     	(default: .highlight) a css selector to scope by|
        yield %|  --tex       	(default: false) render as TeX|
        yield %|  --tex-prefix	(default: RG) a command prefix for TeX|
        yield %|              	implies --tex if specified|
        yield %||
        yield %|available themes:|
        yield %|  #{Theme.registry.keys.sort.join(', ')}|
      end

      def self.parse(argv)
        opts = {
          :theme_name => 'thankful_eyes',
          :tex => false,
          :tex_prefix => 'RG'
        }

        until argv.empty?
          arg = argv.shift
          case arg
          when '--tex'
            opts[:tex] = true
          when '--tex-prefix'
            opts[:tex] = true
            opts[:tex_prefix] = argv.shift
          when /--(\w+)/
            opts[$1.tr('-', '_').to_sym] = argv.shift
          else
            opts[:theme_name] = arg
          end
        end

        new(opts)
      end

      def initialize(opts)
        theme_name = opts.delete(:theme_name)
        theme_class = Theme.find(theme_name) \
          or error! "unknown theme: #{theme_name}"

        @theme = theme_class.new(opts)
        if opts[:tex]
          tex_prefix = opts[:tex_prefix]
          @theme = TexThemeRenderer.new(@theme, prefix: tex_prefix)
        end
      end

      def run
        @theme.render(&method(:puts))
      end
    end

    class List < CLI
      def self.desc
        "list available lexers"
      end

      def self.doc
        return enum_for(:doc) unless block_given?

        yield %|usage: rouge list|
        yield %||
        yield %|print a list of all available lexers with their descriptions.|
      end

      def self.parse(argv)
        new
      end

      def run
        puts "== Available Lexers =="

        Lexer.all.sort_by(&:tag).each do |lexer|
          desc = String.new("#{lexer.desc}")
          if lexer.aliases.any?
            desc << " [aliases: #{lexer.aliases.join(',')}]"
          end
          puts "%s: %s" % [lexer.tag, desc]

          lexer.option_docs.keys.sort.each do |option|
            puts "  ?#{option}= #{lexer.option_docs[option]}"
          end

          puts
        end
      end
    end

    class Guess < CLI
      def self.desc
        "guess the languages of file"
      end

      def self.parse(args)
        new(input_file: args.shift)
      end

      attr_reader :input_file, :input_source

      def initialize(opts)
        @input_file = opts[:input_file] || '-'
        @input_source = FileReader.new(@input_file).read
      end

      def lexers
        Lexer.guesses(
          filename: input_file,
          source: input_source,
        )
      end

      def run
        lexers.each do |l|
          puts "{ tag: #{l.tag.inspect}, title: #{l.title.inspect}, desc: #{l.desc.inspect} }"
        end
      end
    end


  private_class_method
    def self.normalize_syntax(argv)
      out = []
      argv.each do |arg|
        case arg
        when /^(--\w+)=(.*)$/
          out << $1 << $2
        when /^(-\w)(.+)$/
          out << $1 << $2
        else
          out << arg
        end
      end

      out
    end
  end
end
