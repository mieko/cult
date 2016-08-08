require 'cult/template'

module Cult
  module Transferable

    def collection_name
      class_name = self.class.name.split('::')[-1]
      class_name.downcase + 's'
    end

    def remote_path
      File.join(role.remote_path, role_relative_path)
    end

    def role_relative_path
      File.join(collection_name, relative_name)
    end

    def contents(project, role, node)
      erb = Template.new(project: project, role: role, node: node)
      erb.process File.read(path)
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
