# coding: utf-8

# usage: in your rgss3 scripts, put one line of
# ```ruby
# require 'path/to/this/main.rb'
# ```
# then, don't press F12, instead run
# ```cmd
# Game.exe console test
# ```
# that's all, you don't have to modify any codes below

module Rrnide
  #--------------------------------------------------------------------------
  # Debug Part
  # Suppress some runtime errors
  #--------------------------------------------------------------------------

  FULL_ERROR = false

  def self.print_error e, full=FULL_ERROR
    puts "#{e.class}: #{e}"
    e.backtrace.each do |c|
      break if c.start_with?(':1:')
      if parts = c.match(/^(?<file>.+):(?<line>\d+):in `(?<code>.*)'$/)
        next if parts[:file] == __FILE__
        cd = Regexp.escape(File.join(Dir.getwd, ''))
        file = parts[:file].sub(/^#{cd}/, '')
        if inner = file.match(/^\{(?<rgss>\d+)\}$/)
          id = inner[:rgss].to_i
          file = "[#{$RGSS_SCRIPTS[id][1]}]"
        end
        puts "   #{file} #{parts[:line]}: #{parts[:code]}"
      else
        puts "   #{c}"
      end
    end if full
  end

  SuppressedMethods = []

  def self.suppress klass, meth
    unless SuppressedMethods.include? [self, meth]
      puts "suppress #{klass}##{meth}"
      SuppressedMethods << [self, meth]
      old = klass.instance_method meth
      klass.send :define_method, meth do |*args, &blk|
        begin
          old.bind(self).call(*args, &blk)
        rescue Exception => e
          print_error e
          nil
        end
      end
    end
  end

  module Suppress # MyClass.extend Suppress
    def method_added(meth)
      Rrnide.suppress self, meth
    end
  end

  CRAZY = false

  ::Object.extend Suppress if CRAZY

  #--------------------------------------------------------------------------
  # HMR Part
  # Let RM hot reload SCRIPTS_PATH/*.rb
  # To do so, we introduce an `alias_once' method
  #--------------------------------------------------------------------------

  SCRIPTS_PATH = 'Scripts'

  def self.mkdir_p *paths
    paths.each do |path|
      path.tr('\\', '/').gsub(/\/+/, '/').chomp('/').split('/')
          .reduce([]) { |s, x| s[-1] ? s << File.join(s[-1], x) : [x] }
          .each do |path|
        if !File.exist? path
          Dir.mkdir path
        else
          raise Errno::EEXIST unless File.directory? path
        end
      end
    end
  end

  mkdir_p SCRIPTS_PATH

  def self.unpadding str
    indent = str.lines.map { |e| e[/\S/] && e[/^\s+/].size }.compact.min
    str.lines.map { |e| e[/\S/] ? e.slice!(0, indent) && e : "\n" }.join
  end

  EXAMPLE_FILE = File.join(SCRIPTS_PATH, "skip_title.rb")
  unless File.exist? EXAMPLE_FILE
    open(EXAMPLE_FILE, "w") { |f| f.puts unpadding <<-EOF }
      # coding: utf-8
      # @display 跳过标题画面
      # https://taroxd.github.io/rgss/skip_title.html

      class Module
        def alias_once(nevv, old)
          alias_method nevv, old unless method_defined? nevv
        end unless method_defined? :alias_once
      end

      class << SceneManager
        alias_once :_first_scene_class_without_skip_title, :first_scene_class
        def first_scene_class
          DataManager.setup_new_game
          $game_map.autoplay
          Scene_Map
        end if $TEST && !$BTEST
      end
    EOF
  end

  UNINSTALL_BEGIN = unpadding <<-EOF
    (ALIAS_COLLECTION ||= []).clear
    class Module
      alias_method :_alias_once_without_uninstall, :alias_once
      def alias_once(nevv, old)
        _alias_once_without_uninstall(nevv, old)
        ALIAS_COLLECTION << [self, nevv, old]
      end
      ALIAS_COLLECTION << [self, :_alias_once_without_uninstall, :alias_once]
    end
  EOF

  UNINSTALL_END = unpadding <<-EOF
    ALIAS_COLLECTION.each do |klass, nevv, old|
      klass.class_eval { alias_method old, nevv; remove_method nevv }
    end
  EOF

  PLUGINS = {}

  def self.extract_name str
    if line = str.lines.find { |e| e[/^# @display .+/] }
      /^# @display (?<name>.+)/ =~ line
    else
      name = File.basename(file, '.rb')
    end
    name
  end

  def self.safe_load file
    load file
    true
  rescue Exception => e
    print_error e
    false
  end

  def self.update_hotreload
    installed = []
    # reload changed files
    Dir.glob File.join(SCRIPTS_PATH, '*.rb') do |file|
      installed << file
      mtime = File.mtime(file)
      if !PLUGINS[file] || PLUGINS[file][0] != mtime
        content = File.read(file)
        name = extract_name(content)
        puts "reload [#{name}]"
        if !safe_load file
          content = PLUGINS[file] ? PLUGINS[file][1] : ''
        end
        PLUGINS[file] = [mtime, content]
      end
    end
    # remove missing files
    (PLUGINS.keys - installed).each do |file|
      name = extract_name PLUGINS[file][1]
      puts "remove [#{name}]"
      content = [UNINSTALL_BEGIN, PLUGINS[file][1], UNINSTALL_END].join("\n")
      open(file, 'w') { |f| f.puts content }
      safe_load file
      File.delete file
      PLUGINS.delete file
    end
  end

  class << ::Graphics
    alias _update_without_rrnide_hotreload update
    def update
      _update_without_rrnide_hotreload
      Rrnide.update_hotreload
    end
  end

  update_hotreload

  #--------------------------------------------------------------------------
  # Eval(evil?) Part
  # Ask RM to eval some code sync/async
  # Create file.i in VAR_RUN_PATH, sync if file is 'a', otherwise async
  # Result will be written into file.o(marshalled)/file.e(text)
  # The client may want to delete file.{o,e} first
  #--------------------------------------------------------------------------

  VAR_RUN_PATH = 'Scripts/run'

  mkdir_p VAR_RUN_PATH

  TASKS = {}

  def self.evil_task code, file='a'
    ret = eval code, TOPLEVEL_BINDING
    open File.join(VAR_RUN_PATH, "#{file}.o"), 'wb' do |f|
      f.write Marshal.dump ret
    end
    TASKS.delete file
  rescue Exception => e
    open File.join(VAR_RUN_PATH, "#{file}.e"), 'w' do |f|
      f.puts "#{e.class}: #{e}"
      e.backtrace.each do |c|
        break if c.start_with?(':1:')
        if parts = c.match(/^(?<file>.+):(?<line>\d+):in `(?<code>.*)'$/)
          next if parts[:file] == __FILE__
          cd = Regexp.escape(File.join(Dir.getwd, ''))
          file = parts[:file].sub(/^#{cd}/, '')
          if inner = file.match(/^\{(?<rgss>\d+)\}$/)
            id = inner[:rgss].to_i
            file = "[#{$RGSS_SCRIPTS[id][1]}]"
          end
          f.puts "   #{file} #{parts[:line]}: #{parts[:code]}"
        else
          f.puts "   #{c}"
        end
      end
    end
  end

  def self.evil code, async=nil # async=the_uniq_task_id_provided_by_client
    if async
      TASKS[async] = Thread.new code, async, &method(:evil_task)
    else
      evil_task code
    end
  end

  def self.update_evil
    Dir.glob File.join(VAR_RUN_PATH, '*.i') do |file|
      async = File.basename(file, '.i')
      async = nil if async == 'a'
      code = File.read file
      evil code, async
      File.delete file
    end
  end

  class << ::Graphics
    alias _update_without_rrnide_evil update
    def update
      _update_without_rrnide_evil
      Rrnide.update_evil
    end
  end
end
