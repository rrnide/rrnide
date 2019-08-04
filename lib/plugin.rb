# this file is used to act as Plugin Manager
# by design, install = copy script file to destination folder
# and uninstall = delete it from that place
# 
# to realize the dependences and other information
# the manager will parse a simple meta in the comments
# example:
# @id core
# @display The Core
# @desc this is the core script, it should be required by other scripts
# @help
# Some long description here. An empty line will terminate the string.
# @config begin
# SWITCH = true # ruby here, not comment
# @config end
# 
# the rgss/plugin.rb watches the scripts folder
# and reload them if needed
require "fileutils"

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
      'help' => ''
    }
    ret.merge! parse_meta File.read file
  end

  Watch = ['plugins/*.rb']

  def plugins
    Watch.map { |e| Dir[e].select { |f| File.file? f } }.flatten.uniq
         .map { |f| { file: f, meta: parse_file(f), mtime: File.mtime(f) } }
  end

  def install file, proj
    dest = File.join proj, 'Scripts'
    FileUtils.cp_r file, dest, preserve: true
  end

  def uninstall destfile, proj
    File.delete File.join proj, destfile
  end
end
