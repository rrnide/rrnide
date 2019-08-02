
class Mailslot
  DLL = 'System/mailslot.dll'
  SLOT_GAME   = "\\\\.\\mailslot\\rgss_game"
  SLOT_RRNIDE = "\\\\.\\mailslot\\rgss_rrnide"

  unless File.exist? DLL
    msgbox "Not found #{DLL}, which is required to run rrnide!"
    exit 1
  end

  Create = Win32API.new(DLL, 'Create', 'p'  , 'L')
  Open   = Win32API.new(DLL, 'Open'  , 'p'  , 'L')
  Read   = Win32API.new(DLL, 'Read'  , 'LpL', 'L')
  Write  = Win32API.new(DLL, 'Write' , 'LpL', 'L')
  Close  = Win32API.new(DLL, 'Close' , 'L'  , 'L')

  def initialize
    @name = SLOT_GAME
    @server = create_server @name
    @client = nil
  end

  attr_reader :name

  def read
    size = Read.call @server, 0, 0
    return nil if size == 0
    buffer = [].pack("x#{size}")
    size = Read.call @server, buffer, size
    if size != 0
      Marshal.load buffer rescue nil
    end
  end

  def write msg
    msg = Marshal.dump msg
    @client ||= Open.call SLOT_RRNIDE
    written = Write.call @client, msg, msg.bytesize
    if written == 0
      @client = Open.call SLOT_RRNIDE
      if invalid? @client
        @client = nil
        return false
      end
      written = Write.call @client, msg, msg.bytesize
    end
    written != 0
  end

  def dispose
    Close.call @server
    Close.call @client if @client and not invalid? @client
  end

  def create_server name
    handle = Create.call name
    if invalid? handle
      msgbox "Invalid handle: failed to create mailslot server."
      exit 1
    end
    handle
  end

  def invalid? handle
    handle == -1
  end

  def method_missing *args
    write args
  end
end

SlotClient = Mailslot.new

class << STDOUT
  alias _write_without_mailslot write
  def write *args
    _write_without_mailslot *args
    SlotClient.stdout args.join
  end
end

class << STDERR
  alias _write_without_mailslot write
  def write *args
    _write_without_mailslot *args
    SlotClient.stderr args.join
  end
end

def print_error e
  STDERR.puts "#{e.class}: #{e.message}"
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
      STDERR.puts "   #{file} #{parts[:line]}#{code}"
    else
      STDERR.puts "   #{c}"
    end
  end
end

class << Graphics
  alias _update_without_mailslot update
  def update
    _update_without_mailslot
    meth, *args = SlotClient.read
    case meth
    when :eval
      text, id = args
      begin
        value = eval(text.force_encoding('utf-8'), TOPLEVEL_BINDING)
        SlotClient.return value, id
      rescue Exception => e
        print_error e
      end
    end
  end
end
