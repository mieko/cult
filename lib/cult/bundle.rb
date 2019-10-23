require 'rubygems/package'
require 'rubygems/package/tar_writer'

module Cult
  class Bundle
    attr_reader :tar
    def initialize(io, &_block)
      @tar = Gem::Package::TarWriter.new(io)
      if block_given?
        begin
          yield self
        ensure
          @tar.close
          @tar = nil
        end
      end
    end

    def add_file(project, role, node, transferable)
      data = transferable.contents(project, role, node, pwd: role.path)
      tar.add_file(transferable.remote_path, transferable.file_mode) do |io|
        io.write(data)
      end
    end
  end
end
