module Cult
  class CommanderSync
    attr_reader :project, :nodes
    def initialize(project:, nodes:)
      @project, @nodes = project, nodes
    end

    def sync!(roles: nil, passes: nil)
      roles ||= Cult.project.roles
      passes ||= required_passes(roles)

      passes.each do |pass|
        puts Rainbow("Executing pass #{pass}").yellow
        Cult.paramap(nodes) do |node|
          c = Commander.new(project: project, node: node)
          c.sync!(pass: pass, roles: roles)
        end
      end
    end

    def required_passes(roles)
      # searches through every node and extracts which passes have to be ran
      # to satisfy every event task
      nodes.map(&:build_order).flatten.uniq
           .select { |r| roles.nil? ? true : roles.include?(r) }
           .map(&:event_tasks).flatten.map(&:pass).uniq.sort
    end
  end
end
