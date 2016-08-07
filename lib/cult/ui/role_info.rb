require 'rainbow'
require 'rouge'

module Cult
  module UI
    using Rainbow

    class RoleInfo
      attr_reader :argv
      attr_reader :io

      def initialize(argv)
        @argv = argv
        @io = $stdout
      end

      def hr
        io.puts ('-' * 78).white
      end

      def puts(*a)
        io.puts *a
      end

      def role_color(role)
        role.exist? ? role.name.white : role.name.red
      end

      def show_readme(role)
        filename = File.join(role.path, "README.md")
        if File.exist?(filename)
          io.puts "README: ".bold
          hr
          content = File.read(filename)
          io.puts content.white
        end
      end

      def show_includes(role)
        io.print "Direct Includes: ".bold
        pr = role.parent_roles
        if pr.empty?
          puts "(none)".white
        else
          puts pr.map {|r| role_color(r) }.join(" ")
        end
      end

      def show_tree(role, indent = 0, prefix: '  ')
        if indent.zero?
          io.puts "Dependency Tree:".bold
        end

        space = '  ' * indent
        io.puts prefix + space + role_color(role)
        role.parent_roles.each do |pr|
          show_tree(pr, indent + 1)
        end
      end

      def show_build_order(role)
        io.print "Build Order: ".bold
        io.puts role.build_order.map { |dep| role_color(dep) }.join ", "
      end

      def syntax_highlight(text)

        theme = Rouge::Theme.find('molokai')
        lexer = Rouge::Lexer.guess(source: text).new
        formatter = Rouge::Formatters::Terminal256.new(theme)
        formatter.format(lexer.lex(text), &method(:print))
      rescue
        puts text
      end

      def show_tasks(role, summary: false)
        unless role.tasks.empty?
          if summary
            puts "Tasks: ".bold + role.tasks.map(&:name).join(', ').white
          else
            role.tasks.each do |t|
              line = " Task: #{t.name} (serial: #{t.serial})"
              blanks = ' ' *  (78 - line.size)
              puts (line + blanks).inverse
              puts
              syntax_highlight t.content(Cult.project, role, role)
              puts
            end
          end
        end
      end

      def show_files(role, summary: false)
        unless role.files.empty?
          if summary
            puts "Files: ".bold + role.files.map(&:name).join(', ').white
            puts
          else
            role.files.each do |t|
              line = " File: #{t.name}"
              blanks = ' ' *  (78 - line.size)
              puts (line + blanks).inverse
              puts
              syntax_highlight t.content(Cult.project, role, role)
              puts
            end
          end
        end
      end

      def info_page(role)
        Rainbow.enabled = true

        puts "#{role.class.name.split('::')[-1]}: " + role.name.bold
        hr
        puts
        show_includes(role)
        show_build_order(role)
        show_tasks(role, summary: true)
        show_files(role, summary: true)
        show_readme(role)
        show_tree(role)
        puts
        puts
        show_tasks(role, summary: false)
        show_files(role, summary: false)

      end

      def run
        role = Cult.project.roles.find { |r| r.name == argv[0] }
        role ||= Cult.project.nodes.find { |r| r.name == argv[0] }
        info_page(role)
      end
    end

  end
end
