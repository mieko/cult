module Tmux
  module_function
  def tmux(*args)
    system 'tmux', *args.map(&:to_s)
  end

  def resize_pane(target, width: nil, height: nil)
    if (width && height) || (width.nil? && height.nil?)
      fail "only one of width: or height: required"
    end

    k = width ? '-x' : '-y'
    tmux 'resize-pane', '-t', target, k, (width || height)
  end

  def replace_pane(target, command:)
    tmux 'respawn-pane', '-t', target, '-k', command
  end
end
