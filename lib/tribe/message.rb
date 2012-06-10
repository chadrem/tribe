module Tribe
  class Message
    attr_reader :from
    attr_reader :to
    attr_reader :method
    attr_reader :args

    def initialize(from, to, method, *args)
      @from = from
      @to = to
      @method = method
      @args = args
    end
  end
end
