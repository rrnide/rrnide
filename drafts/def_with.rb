class Object
  def def_with meth, &blk
    old = instance_method meth
    define_method meth do |*args, &block|
      blk.call old.bind(self), *args, &block
    end
  end
end
