require 'win32api'

class Mailslot
  DLL_FILE = File.expand_path 'mailslot/mailslot.dll'
  GAME_SLOT = "\\\\.\\mailslot\\rgss_game"
  RRNIDE_SLOT = "\\\\.\\mailslot\\rgss_rrnide"

  unless File.exist? DLL_FILE
    puts "Not found #{DLL_FILE}, which is required to run RRNIDE!"
    exit
  end

  Create = Win32API.new(DLL_FILE, 'Create', 'p'  , 'L')
  Open   = Win32API.new(DLL_FILE, 'Open'  , 'p'  , 'L')
  Read   = Win32API.new(DLL_FILE, 'Read'  , 'LpL', 'L')
  Write  = Win32API.new(DLL_FILE, 'Write' , 'LpL', 'L')
  Close  = Win32API.new(DLL_FILE, 'Close' , 'L'  , 'L')

  def initialize
    @name = RRNIDE_SLOT
    @server = guard_invalid_handle(Create.call(@name), 'CreateMailslot')
    @client = nil
  end

  attr_reader :name

  def read
    size = Read.call @server, 0, 0
    return nil if size == 0
    buffer = [].pack("x#{size}")
    Read.call(@server, buffer, size) != 0
    buffer
  end

  def write message
    @client ||= Open.call(GAME_SLOT)
    written = Write.call(@client, message, message.bytesize)
    if written == 0
      if (@client = Open.call(GAME_SLOT)) == -1
        @client = nil
        return false
      end
      written = Write.call(@client, message, message.bytesize)
    end
    written != 0
  end

  def dispose
    Close.call @server
    Close.call @client if @client
  end

  def guard_invalid_handle handle, msg
    if handle == -1
      puts "Invalid handle: #{msg} failed"
      exit
    end
    handle
  end
end

RrnideServer = Mailslot.new
