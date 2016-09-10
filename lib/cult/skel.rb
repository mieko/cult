require 'fileutils'

module Cult
  class Skel
    SKEL_DIR = File.expand_path(File.join(__dir__, '../../skel'))

    attr_reader :project

    def initialize(project)
      @project = project
    end


    def template
      @erb ||= Template.new(project: project)
    end


    # Skeleton files are files that are copied over for a new project.
    # We allow template files to live in the skeleton directory too, but
    # they're not copied over until needed.
    def skeleton_files
      Dir.glob(File.join(SKEL_DIR, "**", "{.*,*}")).reject do |fn|
        fn.match(/template/i)
      end
    end


    def template_file(name)
      File.join(SKEL_DIR, name)
    end


    def copy_template(name, dst)
      src = template_file(name)
      dst = project.location_of(dst)
      process_file(src, dst)
    end


    def process_file(src, dst = nil)
      dst ||= begin
        relative = src.sub(%r/\A#{Regexp.escape(SKEL_DIR)}/, '')
        project.location_of(relative)
      end

      if File.directory?(src)
        return
      end

      dst, data = case src
        when /\.erb\z/
          [ dst.sub(/\.erb\z/, ''),
            template.process(File.read(src), filename: src)]
        else
          [ dst, File.read(src) ]
        end

      display_name = File.basename(dst) == ".keep" ? File.dirname(dst) : dst

      print "  Creating #{display_name}"
      if File.exist?(dst)
        puts " exists, skipped."
        return
      end


      FileUtils.mkdir_p(File.dirname(dst))

      File.write(dst, data)
      File.chmod(File.stat(src).mode, dst)
      puts
    end


    def copy!
      puts "Creating project from skeleton..."
      FileUtils.mkdir_p(project.path)
      skeleton_files.each do |file|
        process_file(file)
      end
      puts
    end
  end
end
