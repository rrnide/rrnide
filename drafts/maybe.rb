class Maybe
  attr_accessor :obj
  def initialize(obj)
    @obj = obj
  end

  def nothing?
    @obj.nil?
  end

  alias nil? nothing?

  def method_missing(meth, *args, &blk)
    if @obj.respond_to?(meth)
      @obj.send(meth, *args, &blk)
    end
  end
end

def Maybe(obj)
  Maybe.new(obj)
end

alias maybe Maybe

def nothing(*)
  Maybe.new(nil)
end

Nothing = nothing
