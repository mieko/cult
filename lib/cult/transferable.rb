require 'cult/template'

module Cult
  module Transferable

    module ClassMethods
      def collection_name
        name.split('::')[-1].downcase + 's'
      end
    end


    def self.included(cls)
      cls.extend(ClassMethods)
    end


    def collection_name
      self.class.collection_name
    end


    def remote_path
      File.join(role.remote_path, role_relative_path)
    end


    def role_relative_path
      File.join(collection_name, relative_path)
    end


    def binary?
      !! File.read(path, 512).match(/[\x00-\x08]/)
    end


    def contents(project, role, node, pwd: nil)
      if binary?
        File.read(path)
      else
        erb = Template.new(pwd: pwd, project: project, role: role, node: node)
        erb.process File.read(path)
      end
    end


    def name
      prefix = File.join(role.path, collection_name) + "/"
      if path.start_with?(prefix)
        path[prefix.size .. -1]
      end
    end


    def file_mode
      File.stat(path).mode & 0777
    end

  end
end
