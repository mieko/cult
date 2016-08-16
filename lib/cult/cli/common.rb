require 'io/console'

module Cult
  module CLI

    module_function

    def set_project(path)
      Cult.project = Cult::Project.locate(path)
      if Cult.project.nil?
        $stderr.puts "#{$0}: '#{path}' does not contain a valid cult project."
        exit 1
      end
    end

    def quiet=(v)
      @quiet = v
    end

    def quiet?(v)
      @quiet
    end

    def say(v)
      puts v unless @quiet
    end

    def yes=(v)
      @yes = v
    end

    def yes?
      @yes
    end

    def yes_no(msg)
      return true if yes?
      loop do
        print "#{msg} [Y]/n: "
        case $stdin.gets.chomp
          when '', /^[Yy]/
            return true
          when /^[Nn]/
            return false
          else
            $stderr.puts "Unrecognized response"
        end
      end
    end

    def ask(prompt)
      print "#{prompt}: "
      gets.chomp
    end

    def password(prompt)
      STDIN.noecho do
        ask(prompt)
      end
    ensure
      puts
    end

    # it's common for drivers to need the user to visit a URL to
    # confirm an API key or similar.
    def launch_browser(url)
      case RUBY_PLATFORM
        when /darwin/
          system "open", url
        when /mswin|mingw|cygwin/
          system "start", url
        else
          system "xdg-open", url
      end
    end


    # This intercepts GemNeededError and does the installation dance.
    def offer_gem_install
      yield
    rescue GemNeededError => needed
      print <<~EOD
        This driver requires the installation of one or more gem dependencies:

          #{e.gems.inspect}"

        Cult can install them for you.
      EOD

      raise unless yes_no("Install?")

      e.gems.each do |gem|
        cmd = "gem install #{gem}"
        puts "executing: #{cmd}"
        system cmd
      end
      Gem.refresh
      retry
    end
  end
end
