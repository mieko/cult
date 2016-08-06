module Cult
  class Task
    attr_reader :path
    attr_reader :serial
    attr_reader :name
    attr_reader :role

    LEADING_ZEROS = 5
    BASENAME_RE = /\A(\d{#{LEADING_ZEROS},})-([\w-]+)(\..+)?\z/i

    def initialize(role, path)
      @role = role
      @path = path
      @basename = File.basename(path)

      if (m = @basename.match(BASENAME_RE))
        @serial = m[1].to_i
        @name = m[2]
      else
        fail ArgumentError, "invalid task name: #{path}"
      end
    end

    def inspect
      "\#<#{self.class.name} role:#{role&.name.inspect} " +
          "serial:#{serial} name:#{name.inspect}>"
    end
    alias_method :to_s, :inspect

    def self.for_role(project, role)
      Dir.glob(File.join(role.path, "tasks", "*")).map do |filename|
        next unless File.basename(filename).match(BASENAME_RE)
        new(role, filename).tap do |new_task|
          yield new_task if block_given?
        end
      end
    end

  end
end
