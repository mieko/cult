module Cult
  module_function \
  def immutable?
    ENV['CULT_IMMUTABLE'] == '1'
  end
end
