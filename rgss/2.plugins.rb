
class ::Module
  public :include, :define_method, :remove_method
end

class ::Object
  public :define_singleton_method
end

module PluginManager
  module_function

  @old_methods = {} # klass => { meth_name => [older_meth, old_meth] }
  @singleton_old_methods = {}

  def size
    [@old_methods, @singleton_old_methods].map { |e|
      e.values.map { |e| e.values.map(&:size).inject(:+) }.inject(:+)
    }.inject(:+)
  end

  def save_old klass, meth
    @old_methods[klass] ||= {}
    @old_methods[klass][meth.name] ||= []
    @old_methods[klass][meth.name] << meth
  end

  def singleton_save_old singleton, meth
    @singleton_old_methods[singleton] ||= {}
    @singleton_old_methods[singleton][meth.name] ||= []
    @singleton_old_methods[singleton][meth.name] << meth
  end

  def restore_old klass, name
    stack = @old_methods[klass][name]
    stack.pop
    if stack.last
      klass.define_method name, stack.last
    else
      klass.remove_method name
    end
  end

  def singleton_restore_old singleton, name
    stack = @singleton_old_methods[singleton][name]
    stack.pop
    if stack.last
      singleton.define_singleton_method name, stack.last
    else
      singleton.singleton_class.remove_method name
    end
  end

  def save_class *klasses
    klasses.each do |klass|
      klass.instance_methods.each do |name|
        save_old klass, klass.instance_method(name)
      end
    end
  end

  def save_singleton *singletons
    singletons.each do |singleton|
      singleton.methods.each do |name|
        singleton_save_old singleton, singleton.method(name)
      end
    end
  end

  def save_any *args
    args.each do |a|
      if a.is_a? Module
        save_class a
        save_singleton a
      end
    end
  end

  def blacklist? o, c
    [[DL, :CdeclCallbackAddrs],
     [DL, :CdeclCallbackProcs],
     [DL, :StdcallCallbackAddrs],
     [DL, :StdcallCallbackProcs]].any? { |a, b| a == o && b == c }
  end

  def save_recursive o=Object, v=[]
    return if v.include?(o)
    v << o
    save_any o
    o.constants(false).each do |c|
      next if blacklist?(o, c)
      m = o.const_get(c)
      if m.respond_to? :constants
        save_recursive m, v
      end
    end
  end

  def save_all
    t = Time.now
    save_recursive
    puts "Time elapsed #{Time.now - t}s, saved #{size} methods."
  end

  @scripts = [[nil, [], nil]]
  singleton_class.class_eval { attr_reader :scripts }

  module HookMethodAdded
    def method_added(sym)
      PluginManager.scripts.last[1] << [:i, self, sym]
      PluginManager.save_old self, instance_method(sym)
    end

    def singleton_method_added(sym)
      PluginManager.scripts.last[1] << [:s, self, sym]
      PluginManager.singleton_save_old self, method(sym)
    end
  end

  [
    ::Object, ::Audio, ::Graphics, ::Input, ::RPG,
    ::Vocab, ::Sound, ::Cache,
    ::DataManager, ::SceneManager, ::BattleManager
  ].each do |mod|
    mod.extend HookMethodAdded
  end

  def install file
    puts "+ #{file}"
    scripts << [file, [], File.mtime(file)]
    load file
    scripts.last[1].each do |t, obj, sym|
      t = { i: '#', s: '.' }[t]
      puts "  + #{obj}#{t}#{sym}"
    end
  rescue Exception => e
    print_full_error e
    uninstall file
  end

  def uninstall file
    count = 0
    reinstall = []
    puts "- #{file}"
    scripts.reverse_each do |name, side_effects, _|
      side_effects.reverse_each do |t, obj, meth|
        case t
        when :i
          restore_old obj, meth
        when :s
          singleton_restore_old obj, meth
        end
        t = { i: '#', s: '.' }[t]
        puts "  - #{obj}#{t}#{meth}"
      end.clear
      break if file == name
      count += 1
      reinstall << name
    end
    scripts.pop(count)
    reinstall.reverse_each do |name|
      install name
    end
  end

  Watch = ['Scripts/*.rb']

  def include? file
    !!scripts.find { |n, _, m| n == file && m == File.mtime(file) }
  end

  def need_uninstall? file
    !!scripts.find { |n, *| n == file }
  end

  def diff
    files = Watch.map { |e| Dir[e].select { |f| File.file? f } }.flatten.uniq
    files.reject { |file| include? file }
  end

  def update
    diff.each do |file|
      uninstall file if need_uninstall? file
      install file
    end
  end

  save_all
end

class << ::Graphics
  alias _update_without_plugin_manager update
  def update
    _update_without_plugin_manager
    PluginManager.update
  end
end
