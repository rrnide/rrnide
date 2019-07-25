require 'fiddle'
require 'fiddle/types'
require 'fiddle/import'

class Mailslot
  DLL_FILE = File.expand_path 'mailslot/mailslot.dll'
  GAME_SLOT = "\\\\.\\mailslot\\rgss_game"
  RRNIDE_SLOT = "\\\\.\\mailslot\\rgss_rrnide"

  unless File.exist? DLL_FILE
    puts "Not found #{DLL_FILE}, which is required to run RRNIDE!"
    exit
  end

  module Lib
    extend Fiddle::Importer
    dlload DLL_FILE
    include Fiddle::Win32Types
    extern 'HANDLE Create(LPSTR)'
    extern 'HANDLE Open(LPSTR)'
    extern 'DWORD Read(HANDLE, PVOID, DWORD)'
    extern 'DWORD Write(HANDLE, PVOID, DWORD)'
    extern 'BOOL Close(HANDLE)'
  end

  # Create = Win32API.new(DLL_FILE, 'Create', 'p'  , 'L')
  # Open   = Win32API.new(DLL_FILE, 'Open'  , 'p'  , 'L')
  # Read   = Win32API.new(DLL_FILE, 'Read'  , 'LpL', 'L')
  # Write  = Win32API.new(DLL_FILE, 'Write' , 'LpL', 'L')
  # Close  = Win32API.new(DLL_FILE, 'Close' , 'L'  , 'L')

  def initialize
    @name = RRNIDE_SLOT
    @server = guard_invalid_handle(Lib.Create(@name), 'CreateMailslot')
    @client = nil
  end

  attr_reader :name

  def read
    size = Lib.Read @server, 0, 0
    return nil if size == 0
    buffer = [].pack("x#{size}")
    Lib.Read(@server, buffer, size) != 0
    buffer
  end

  def write message
    @client ||= Lib.Open(GAME_SLOT)
    written = Lib.Write(@client, message, message.bytesize)
    if written == 0
      if (@client = Lib.Open(GAME_SLOT)) == -1
        @client = nil
        return false
      end
      written = Lib.Write(@client, message, message.bytesize)
    end
    written != 0
  end

  def dispose
    Lib.Close @server
    Lib.Close @client if @client
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
