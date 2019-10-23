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

    # Task files are executable by anyone: this makes re-exec'ing
    # tasks as another user trivial.
    def file_mode
      super | 0o111
    end

    def self.spawn(role, path)
      [BuildTask, EventTask].each do |task_cls|
        if task_cls.valid_name?(File.basename(path))
          return task_cls.new(role, path)
        end
      end
      nil
    end

    def self.all_for_role(_project, role)
      fail ArgumentError if block_given?

      Dir.glob(File.join(role.path, "tasks", "*")).sort.map do |path|
        spawn(role, path)
      end.compact.to_named_array
    end
  end

  class BuildTask < Task
    LEADING_ZEROS = 3
    BASENAME_RE = /\A(\d{#{LEADING_ZEROS},})-([\w-]+)(\..+)?\z/i.freeze

    def self.valid_name?(basename)
      basename.match?(BASENAME_RE)
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
      basename = format("%0#{LEADING_ZEROS}d-%s", serial, name)
      new(role, File.join(role.path, collection_name, basename))
    end
  end

  class EventTask < Task
    EVENT_TYPES = [:sync].freeze
    EVENT_RE = /^(#{EVENT_TYPES.join('|')})(?:\-P(\d+))?\-?/.freeze

    attr_reader :event
    attr_reader :pass

    def self.valid_name?(basename)
      basename.match?(EVENT_RE)
    end

    def initialize(role, path)
      super
      @event = event_name(name)
      @pass = pass_name(name)
    end

    private

    def event_name(basename)
      basename.match(EVENT_RE)[1].to_sym
    end

    def pass_name(basename)
      basename.match(EVENT_RE)[2].to_i
    end
  end
end
