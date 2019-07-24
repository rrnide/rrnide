
class Mailslot
  DLL_FILE = 'System/mailslot.dll'
  GAME_SLOT = "\\\\.\\mailslot\\rgss_game"
  RRNIDE_SLOT = "\\\\.\\mailslot\\rgss_rrnide"

  unless File.exist? DLL_FILE
    msgbox "Not found #{DLL_FILE}, which is required to run RRNIDE!"
    exit
  end

  Create = Win32API.new(DLL_FILE, 'Create', 'p'  , 'L')
  Open   = Win32API.new(DLL_FILE, 'Open'  , 'p'  , 'L')
  Read   = Win32API.new(DLL_FILE, 'Read'  , 'LpL', 'L')
  Write  = Win32API.new(DLL_FILE, 'Write' , 'LpL', 'L')
  Close  = Win32API.new(DLL_FILE, 'Close' , 'L'  , 'L')

  def initialize
    @name = GAME_SLOT
    @server = guard_invalid_handle(Create.call(@name), 'CreateMailslot')
    @client = nil
  end

  attr_reader :name

  def read
    size = Read.call @server, 0, 0
    return nil if size == 0
    buffer = [].pack("x#{size}")
    Read.call(@server, buffer, size)
    buffer.force_encoding('utf-8')
  end

  def write message
    @client ||= Open.call(RRNIDE_SLOT)
    written = Write.call(@client, message.dup, message.bytesize)
    if written == 0
      if (@client = Open.call(RRNIDE_SLOT)) == -1
        @client = nil
        return false
      end
      written = Write.call(@client, message.dup, message.bytesize)
    end
    written != 0
  end

  def guard_invalid_handle handle, msg
    if handle == -1
      msgbox "Invalid handle: #{msg} failed"
      exit
    end
    handle
  end

  def dispose
    Close.call @server
    Close.call @client if @client
  end
end

RrnideClient = Mailslot.new

class << STDOUT
  alias _write_without_mailslot write
  def write *args
    _write_without_mailslot *args
    RrnideClient.write args.map(&:to_s).join
  end
end

class << Graphics
  alias _update_without_mailslot update
  def update
    if text = RrnideClient.read
      STDERR.puts ">> #{text}"
      begin
        ret = eval text, TOPLEVEL_BINDING, '<Console>'
        puts "=> #{ret.inspect}"
      rescue Exception => e
        print "=> "
        print_full_error e
      end
    end
    _update_without_mailslot
  end
end
