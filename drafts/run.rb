if ARGV.size < 2
  puts "ruby #$0 test.rb XP"
  exit
end

require 'fileutils'
include FileUtils

file, folder = ARGV
open 'main.rb', 'w' do |f|
  f.puts DATA.read.gsub '<file>', file
  f.puts File.read file
end
system "#{File.join(folder, 'Game.exe')} #{folder[/XP/] ? 'debug' : 'test'}"

__END__
# coding: utf-8

alias $TEST $DEBUG unless defined? $TEST

if $TEST # TODO: remove below
  def api(f)
    a=($api||={})[f];return a if a;lambda{|*a|%w[kernel32 user32 msvcrt].each{|d|break($api[f]=Win32API.new(d,f,a.map{|e|Integer===e ? 'i': 'p'},'i')).call(*a)rescue next}}
  end

  def buf(t=())
    t ?$buf=[].pack("x#{($buf_t=t).scan(/(\w)(\d+)?/).inject(0){|s,(c,i)|s+('AaxZ'.include?(c)?1:2**('CSLQ'.index c.upcase))*(i||1).to_i}}"):$buf.unpack($buf_t)
  end

  hwnd = api('GetActiveWindow').call
  api('AllocConsole').call
  api('SetConsoleTitle').call('RGSS Console')
  COUT = api('GetStdHandle').call(-12)
  api('GetConsoleScreenBufferInfo').call COUT, buf('S11')
  CWIDTH = buf[7] - buf[5] + 1
  def enable_ansi_color
    hout = api('GetStdHandle').call(-12)
    api('GetConsoleMode').call(hout, buf('L'))
    api('SetConsoleMode').call(hout, buf[0] | 4)
  end
  enable_ansi_color
  api('SetForegroundWindow').call hwnd

  def print(*a)
    a.each do |s|
      m2w = api('MultiByteToWideChar')
      l = m2w.call(65001, 0, s = "#{s}", -1, 0, 0)
      m2w.call(65001, 0, s, -1, buf("a#{l * 2}"), l)
      w2m = api('WideCharToMultiByte')
      l = w2m.call(0, 0, s = buf[0], -1, 0, 0, 0, 0)
      w2m.call(0, 0, s, -1, buf("A#{l}"), l, 0, 0)
      l = api('lstrlen').call(s = buf[0])
      api('WriteConsole').call(api('GetStdHandle').call(-12), s, l, 0, 0)
    end
  end

  def puts(*a)
    print *a.map { |e| (s = "#{e}")[-1] == "\n"[0] ? s : "#{s}\n" }
  end

  def p(*a)
    puts *a.map { |e| e.inspect }
  end

  Font.default_name = ['更纱黑体 SC']

  class << Graphics
    alias _hotreload_update update
    def update
      _hotreload_update
      _mtime = File.mtime '../<file>'
      if _mtime != @_mtime
        begin
          puts " #{Time.new.ctime} ".rjust CWIDTH, '-'
          eval File.read('../<file>'), TOPLEVEL_BINDING
        rescue => e
          puts "\e[97m#{e.class}: \e[4m#{e}\e[0m"
        rescue SyntaxError => e
          puts "not a valid ruby"
        end
        @_mtime = _mtime
      end
    end
  end
else
  def p(*)
  end
  def print(*)
  end
  def puts(*)
  end
end

if $TEST # 跳过标题
  if defined? SceneManager
    def SceneManager.first_scene_class
      DataManager.setup_new_game
      $game_map.autoplay
      Scene_Map
    end
  elsif defined? Hangup
    class Scene_Title
      def main
        $data_actors        = load_data("Data/Actors.rxdata")
        $data_classes       = load_data("Data/Classes.rxdata")
        $data_skills        = load_data("Data/Skills.rxdata")
        $data_items         = load_data("Data/Items.rxdata")
        $data_weapons       = load_data("Data/Weapons.rxdata")
        $data_armors        = load_data("Data/Armors.rxdata")
        $data_enemies       = load_data("Data/Enemies.rxdata")
        $data_troops        = load_data("Data/Troops.rxdata")
        $data_states        = load_data("Data/States.rxdata")
        $data_animations    = load_data("Data/Animations.rxdata")
        $data_tilesets      = load_data("Data/Tilesets.rxdata")
        $data_common_events = load_data("Data/CommonEvents.rxdata")
        $data_system        = load_data("Data/System.rxdata")
        $game_system = Game_System.new
        Graphics.frame_count = 0
        $game_temp          = Game_Temp.new
        $game_system        = Game_System.new
        $game_switches      = Game_Switches.new
        $game_variables     = Game_Variables.new
        $game_self_switches = Game_SelfSwitches.new
        $game_screen        = Game_Screen.new
        $game_actors        = Game_Actors.new
        $game_party         = Game_Party.new
        $game_troop         = Game_Troop.new
        $game_map           = Game_Map.new
        $game_player        = Game_Player.new
        $game_party.setup_starting_members
        $game_map.setup($data_system.start_map_id)
        $game_player.moveto($data_system.start_x, $data_system.start_y)
        $game_player.refresh
        $game_map.autoplay
        $game_map.update
        $scene = Scene_Map.new
      end
    end
  else
    class Scene_Title
      def start
        super
        load_database
        create_game_objects
        check_continue
        create_title_graphic
        create_command_window
        command_new_game
      end
    end
  end
end
