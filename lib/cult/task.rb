module Cult
  class Task
    include Transferable
    include SingletonInstances

    attr_reader :role
    attr_reader :path
    attr_reader :name

    def initialize(role, path)
      @role = role
      @path = path
      @name = File.basename(path)
    end


    def self.collection_name
      "tasks"
    end


    def relative_path
      File.basename(path)
    end


    def file_mode
      super | 0100
    end


    def self.spawn(role, path)
      [BuildTask, EventTask].each do |task_cls|
        if task_cls.valid_name?(File.basename(path))
          return task_cls.new(role, path)
        end
      end
      nil
    end


    def self.all_for_role(project, role)
      fail ArgumentError if block_given?

      Dir.glob(File.join(role.path, "tasks", "*")).sort.map do |path|
        spawn(role, path)
      end.compact.to_named_array
    end
  end


  class BuildTask < Task
    LEADING_ZEROS = 3
    BASENAME_RE = /\A(\d{#{LEADING_ZEROS},})-([\w-]+)(\..+)?\z/i


    def self.valid_name?(basename)
      !! basename.match(BASENAME_RE)
    end


    attr_reader :serial

    def initialize(role, path)
      super

      if (m = BASENAME_RE.match(name))
        @serial = m[1].to_i
        @name = m[2]
      else
        fail ArgumentError
      end
    end


    def self.from_serial_and_name(role, serial:, name:)
      basename = sprintf("%0#{LEADING_ZEROS}d-%s", serial, name)
      new(role, File.join(role.path, collection_name, basename))
    end
  end


  class EventTask < Task
    EVENT_TYPES = [:sync]
    EVENT_RE = /^(#{EVENT_TYPES.join('|')})\-?/

    attr_reader :event


    def self.valid_name?(basename)
      !! basename.match(EVENT_RE)
    end


    def initialize(role, path)
      super
      @event = event_name(name)
    end


    def event_name(basename)
      basename.match(EVENT_RE)[1].to_sym
    end

  end
end
