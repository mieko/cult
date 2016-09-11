module Cult
  class Task
    include Transferable
    include SingletonInstances

    attr_reader :path
    attr_reader :role
    attr_reader :serial
    attr_reader :name
    attr_reader :type

    LEADING_ZEROS = 3
    BASENAME_RE = /\A(\d{#{LEADING_ZEROS},})-([\w-]+)(\..+)?\z/i
    EVENTS = [:sync]


    def initialize(role, path)
      @role = role
      @path = path
      @basename = File.basename(path)

      unless self.class.valid_task_name?(@basename)
        fail ArgumentError, "invalid task name: #{path}"
      end

      if (m = @basename.match(BASENAME_RE))
        @type = :build
        @serial = m[1].to_i
        @name = m[2]
      elsif EVENTS.map(&:to_s).include?(@basename)
        @type = :event
        @serial = nil
        @name = @basename
      else
        fail "WTF"
      end
    end


    def self.from_serial_and_name(role, serial:, name:)
      basename = sprintf("%0#{LEADING_ZEROS}d-%s", serial, name)
      new(role, File.join(role.path, collection_name, basename))
    end


    def relative_path
      File.basename(path)
    end


    def build_task?
      type == :build
    end


    def event_task?
      type != :build
    end


    def inspect
      "\#<#{self.class.name} type: #{type} role:#{role&.name.inspect} " +
          "serial:#{serial} name:#{name.inspect}>"
    end
    alias_method :to_s, :inspect


    def file_mode
      super | 0100
    end

    def self.valid_task_name?(basename)
      EVENTS.map(&:to_s).include?(basename) || basename.match(BASENAME_RE)
    end


    def self.all_for_role(project, role)
      Dir.glob(File.join(role.path, "tasks", "*")).map do |filename|
        next unless valid_task_name?(File.basename(filename))
        new(role, filename).tap do |new_task|
          yield new_task if block_given?
        end
      end.compact.to_named_array
    end
  end
end
