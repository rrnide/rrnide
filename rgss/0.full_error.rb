# coding: utf-8
#==============================================================================
# FullError.rb
#==============================================================================
# @plugindesc Show full backtrace when error occurs.
# @author hyrious
#
# @help This plugin does not provide plugin commands.

def print_full_error(e)
  puts "#{e.class}: #{e.message}"
  e.backtrace.each do |c|
    break if c.start_with?(':1:')
    if parts = c.match(/^(?<file>.+):(?<line>\d+)(?::in `(?<code>.*)')?$/)
      next if parts[:file] == __FILE__
      cd = Regexp.escape(File.join(Dir.getwd, ''))
      file = parts[:file].sub(/^#{cd}/, '')
      if inner = file.match(/^\{(?<rgss>\d+)\}$/)
        id = inner[:rgss].to_i
        file = "[#{$RGSS_SCRIPTS[id][1]}]"
      end
      code = parts[:code] && ": #{parts[:code]}"
      puts "   #{file} #{parts[:line]}#{code}"
    else
      puts "   #{c}"
    end
  end
end

# @mod rgss_main
alias _full_error_rgss_main rgss_main
def rgss_main(*args, &blk)
  _full_error_rgss_main(*args, &blk)
rescue Exception => e
  print_full_error(e)
  rgss_stop
end

class Game_Interpreter
  # @mod Game_Interpreter#command_355
  alias _full_error_command_355 command_355
  def command_355
    begin
      _full_error_command_355
    rescue Exception
      event = get_character(0)
      name = event.instance_variable_get(:@event).name
      print "at map #@map_id #{$game_map.display_name}"
      puts ", event #@event_id #{name} (#{event.x}, #{event.y})"
      raise
    ensure
      $@.shift if $@
    end
  end
end
