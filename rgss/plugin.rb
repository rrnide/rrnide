
class ::Module
  public :include, :define_method, :remove_method
end

class ::Object
  public :define_singleton_method
end

module PluginManager
  module_function

  def parse_meta text
    ret = {}
    is_help = false
    is_block_comment = false
    text.force_encoding('utf-8').each_line.with_index do |line, i|
      if is_block_comment
        next is_block_comment = false if line.start_with? '=end'
      elsif line.start_with? '=begin'
        next is_block_comment = true
      elsif line.slice!(/^\s*#\s?/)
        # so this is a single-line comment
      else
        next
      end
      if /^\s*@(?<key>\w+)(\s+(?<value>.+))?$/ =~ line
        is_help = false
        case key
        when 'require'
          ret['require'] = value.scan(/\w+/)
        when 'config'
          ret['config'] ||= []
          case value
          when 'begin'
            ret['config'] << [i + 1]
          when 'end'
            ret['config'][-1] << i - 1
          end
        when 'help'
          ret[key] = (value ? "#{value}\n" : '')
          is_help = true
        else
          ret[key] = value
        end
      elsif is_help
        next is_help = false if line.empty?
        ret['help'] << line
      end
    end
    ret
  end

  def parse_file file
    id = File.basename file, '.rb'
    ret = {
      'id' => id,
      'display' => id,
      'require' => [],
      'author' => 'unknown',
      'desc' => 'this plugin does not provide any description',
      'help' => ''
    }
    ret.merge parse_meta File.read file
  end

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
  @metas = {}
  singleton_class.class_eval { attr_reader :scripts, :metas }

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
    meta = parse_file file
    deps = meta['require'].all? { |id| metas.find { |f, m| m['id'] == id } }
    return unless deps
    puts "+ #{file}"
    scripts << [file, [], File.mtime(file)]
    metas[file] = meta
    load file
    scripts.last[1].each do |t, obj, sym|
      t = { i: '#', s: '.' }[t]
      puts "  + #{obj}#{t}#{sym}"
    end
  rescue Exception => e
    print_error e
    uninstall file
  end

  def uninstall file
    count = 0
    reinstall = []
    puts "- #{file}"
    scripts.reverse_each do |name, side_effects, _mtime|
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
      count += 1
      break if file == name
      reinstall << name
      metas.delete name
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
    files = files.reject { |file| include? file }
    files += scripts.drop(1).map { |f, *| f }.reject { |f| File.exist? f }
    files.uniq
  end

  def update
    until (files = diff).empty?
      files.reverse_each do |file|
        uninstall file if need_uninstall? file
      end
      files.each do |file|
        install file if File.exist? file
      end
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

PluginManager.update
