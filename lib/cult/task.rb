require 'cult/transferable'
require 'cult/named_array'

module Cult
  class Task
    include Transferable

    attr_reader :path
    attr_reader :role
    attr_reader :serial
    attr_reader :name

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


    def self.from_serial_and_name(role, serial:, name:)
      basename = sprintf("%0#{LEADING_ZEROS}d-%s", serial, name)
      new(role, File.join(role.path, collection_name, basename))
    end


    def relative_path
      File.basename(path)
    end


    def inspect
      "\#<#{self.class.name} role:#{role&.name.inspect} " +
          "serial:#{serial} name:#{name.inspect}>"
    end
    alias_method :to_s, :inspect


    def file_mode
      super | 0100
    end


    def self.all_for_role(project, role)
      Dir.glob(File.join(role.path, "tasks", "*")).map do |filename|
        next unless File.basename(filename).match(BASENAME_RE)
        new(role, filename).tap do |new_task|
          yield new_task if block_given?
        end
      end.compact.to_named_array
    end

  end
end
