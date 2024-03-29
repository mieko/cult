require 'io/console'
require 'shellwords'
require 'cult/cli/table_extensions'
require 'cult/cli/cri_extensions'

module Cult
  module CLI

    class CLIError < RuntimeError
    end

    module_function

    # This sets the global project based on a directory
    def set_project(path)
      Cult.project = Cult::Project.locate(path)
      if Cult.project.nil?
        fail CLIError, "#{path} does not contain a valid Cult project"
      end
    end

    # Quiet mode controls how verbose `say` is
    def quiet=(bool)
      @quiet = bool
    end

    def quiet?
      @quiet
    end

    def say(msg)
      puts msg unless @quiet
    end

    # yes=true automatically answers yes to "yes_no" questions.
    def yes=(value)
      @yes = value
    end

    def yes?
      @yes
    end

    # Asks a yes or no question with promp.  The prompt defaults to "Yes".  If
    # Cli.yes=true, true is returned without showing the prompt.
    def yes_no?(prompt, default: true)
      return true if yes?

      default = case default
        when :y, :yes
          true
        when :n, :no
          false
        when true, false
          default
        else
          fail ArgumentError, "invalid :default"
      end

      loop do
        y =  default ? Rainbow('Y').bright : Rainbow('y').darkgray
        n = !default ? Rainbow('N').bright : Rainbow('n').darkgray

        begin
          print "#{prompt} #{y}/#{n}: "
          case $stdin.gets.chomp
            when ''
              return default
            when /^[Yy]/
              return true
            when /^[Nn]/
              return false
            else
              warn "Unrecognized response"
          end
        rescue Interrupt
          puts
          raise
        end
      end
    end

    # Asks the user a question, and returns the response.  Ensures a newline
    # exists after the response.
    def ask(prompt)
      print "#{prompt}: "
      $stdin.gets.chomp
    end

    def prompt(*args)
      ask(*args)
    end

    # Disables echo to ask the user a password.
    def password(prompt)
      STDIN.noecho do
        begin
          ask(prompt)
        ensure
          puts
        end
      end
    end

    # it's common for drivers to need the user to visit a URL to
    # confirm an API key or similar.  This does this in the most
    # compatable way I know.
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

    # We actually want "base 47", so we have to generate substantially more
    # characters than len.  The method already generates 1.25*len characters,
    # but is offset by _ and - that we discard.  With the other characters we
    # discard, we usethe minimum multiplier which makes a retry "rare" (every
    # few thousand ids at 6 len), then handle that case.
    def unique_id(len = 8)
      @uniq_id_disallowed ||= /[^abcdefhjkmnpqrtvwxyzABCDEFGHJKMNPQRTVWXY2346789]/
      candidate = SecureRandom.urlsafe_base64((len * 2.1).ceil).gsub(@uniq_id_disallowed, '')
      fail RangeError if candidate.size < len

      candidate[0...len]
    rescue RangeError
      retry
    end

    # v is an option or argv value from a user, label: is the name of it.
    #
    # This asserts that `v` is in the collection `from`, and returns it.
    # if `exist` is false, it verifies that v is NOT in the collection and
    # returns v.
    #
    # As a convenience, `from` can be a class like Role, which will imply
    # 'Cult.project.roles'
    #
    # CLIError is raised if these invariants are violated
    def fetch_item(v, from:, label: nil, exist: true, method: :fetch)
      implied_from = case
        when from == Driver
          Cult::Drivers.all
        when from == Provider
          Cult.project.providers
        when from == Role
          Cult.project.roles
        when from == Node
          Cult.project.nodes
      end

      label ||= implied_from ? from.name.split('::')[-1].downcase : nil
      from = implied_from

      fail ArgumentError, "label cannot be implied" if label.nil?

      unless [:fetch, :all].include?(method)
        fail ArgumentError, "method must be :fetch or :all"
      end

      # We got no argument
      fail CLIError, "Expected #{label}" if v.nil?

      if exist
        begin
          from.send(method, v).tap do |r|
            # Make sure
            fail KeyError if method == :all && r.empty?
          end
        rescue KeyError
          fail CLIError, "#{label} does not exist: #{v}"
        end
      else
        fail CLIError, "#{label} already exists: #{v}" if from.key?(v)

        v
      end
    end

    # Takes a list of keys and returns an array of objects that correspond
    # to any of them.
    def fetch_items(*keys, **kwargs)
      keys.flatten.map do |key|
        fetch_item(key, method: :all, **kwargs)
      end.flatten
    end

    # This intercepts GemNeededError and does the installation dance.  It looks
    # a bit hairy because it has a few resumption points, e.g., attempts user
    # gem install, and if that fails, tries the sudo gem install.
    def offer_gem_install(&block)
      prompt_install = ->(gems) do
        unless quiet?
          print <<~MSG
            This driver requires the installation of one or more gems:

              #{gems.inspect}

            Cult can install them for you.
          MSG
        end
        yes_no?("Install?")
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
            raise unless sudo || prompt_install.call(needed.gems)

            needed.gems.each do |gem|
              success = try_install.call(gem, sudo: sudo)
              unless success
                if sudo
                  puts "Nothing seemed to have worked.  Giving up."
                  puts "The gems needed are #{needed.gems.inspect}."
                else
                  puts "It doesn't look like that went well."

                  if yes_no?("Retry with sudo?")
                    throw :sudo_attempt, true
                  end
                end
                raise
              end
            end

            # We exit our non-loop: Everything went fine.
            break
          end
        end

        # Everything went fine, we need to retry the user-supplied block.
        Gem.refresh
        retry
      end
    end
  end
end
