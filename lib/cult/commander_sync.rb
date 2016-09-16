module Cult
  class CommanderSync
    attr_reader :project, :nodes
    def initialize(project:, nodes:)
      @project, @nodes = project, nodes
    end

    def sync!(passes: nil)
      if passes.nil? || passes.empty?
        puts "calculating passes"
        passes = required_passes
      end

      passes.each do |pass|
        puts Rainbow("Executing pass #{pass}").yellow
        Cult.paramap(nodes) do |node|
          c = Commander.new(project: project, node: node)
          c.sync!(pass: pass)
        end
      end
    end

    def required_passes
      # searches through every node and extracts which passes have to be ran
      # to satisfy every event task
      nodes.map(&:roles).flatten.uniq
           .map(&:event_tasks).flatten.map(&:pass).uniq.sort
    end
  end
end
