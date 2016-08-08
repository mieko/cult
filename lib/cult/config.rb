module Cult
  module_function
  def project=(project)
    @project = project
  end

  def project
    @project
  end

  # This is a a mode we're considering: when it's set, certain objects
  # will be frozen when they're created, and creating a "logically the same"
  # instance (e.g., role with same name in the same project) will return
  # the actual same object each time.
  #
  # I'm not sure if we'll commit to this, but having this toggle lets us
  # easily see what breaks.
  def immutable?
    ENV['CULT_IMMUTABLE'] == '1'
  end

end
