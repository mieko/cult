require 'io/console'
require 'shellwords'

module Cult
  module CLI

    class CliError < RuntimeError
    end

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

    def quiet?
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
        print "#{msg} #{Rainbow('Y').bright}/#{Rainbow('n').darkgray}: "
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
      $stdin.gets.chomp
    ensure
      puts
    end
    alias_method :prompt, :ask

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

    def require_argument(v, type:, label:, project: Cult.project, exist: nil)
      collection = case
        when type == Role;   project.roles
        when type == Node;   project.nodes
        when type == Driver; project.drivers
      end

      if exist == false
        unless collection[v].nil?
          fail CliError, "#{label} is already an existing #{type.name}"
        end
        true
      else
        begin
          return collection.fetch(v)
        rescue KeyError
          fail CliError, "Expected #{label} to be a #{type.name}"
        end
      end
    end


    # This intercepts GemNeededError and does the installation dance.  It looks
    # a bit hairy because it has a few resumption points, e.g., attempts user
    # gem install, and if that fails, tries the sudo gem install.
    def offer_gem_install(&block)
      prompt_install = ->(gems) do
        unless quiet?
          print <<~EOD
            This driver requires the installation of one or more gems:

              #{gems.inspect}

            Cult can install them for you.
          EOD
        end
        yes_no("Install?")
      end

      try_install = ->(gem, sudo: false) do
        cmd = "gem install #{Shellwords.escape(gem)}"
        cmd = "sudo #{cmd}" if sudo
        puts "executing: #{cmd}"
        system cmd
        $?.success?
      end

      begin
        yield
      rescue ::Cult::Driver::GemNeededError => needed
        sudo = false
        loop do
          sudo = catch :sudo_attempt do
            # We don't want to show this again on a retry
            raise unless sudo || prompt_install.(needed.gems)

            needed.gems.each do |gem|
              success = try_install.(gem, sudo: sudo)
              if !success
                if sudo
                  puts "Nothing seemed to have worked.  Giving up."
                  puts "The gems needed are #{needed.gems.inspect}."
                  raise
                else
                  puts "It doesn't look like that went well."
                  if yes_no("Retry with sudo?")
                    throw :sudo_attempt, true
                  end
                  raise
                end
              end
            end

            # We exit our non-loop: Everything went fine.
            break
          end
        end

        Gem.refresh
        retry
      end
    end
  end
end
