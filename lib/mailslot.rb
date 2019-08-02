require 'fiddle'
require 'fiddle/types'
require 'fiddle/import'

class Mailslot
  DLL = File.expand_path 'lib/mailslot.dll'
  SLOT_GAME   = "\\\\.\\mailslot\\rgss_game"
  SLOT_RRNIDE = "\\\\.\\mailslot\\rgss_rrnide"

  unless File.exist? DLL
    puts "Not found #{DLL}, which is required to run rrnide!"
    exit 1
  end

  module Dll
    extend Fiddle::Importer
    dlload DLL
    include Fiddle::Win32Types
    extern 'HANDLE Create(LPSTR)'
    extern 'HANDLE Open(LPSTR)'
    extern 'DWORD Read(HANDLE, PVOID, DWORD)'
    extern 'DWORD Write(HANDLE, PVOID, DWORD)'
    extern 'BOOL Close(HANDLE)'
  end

  def initialize
    @name = SLOT_RRNIDE
    @server = create_server @name
    @client = nil
  end

  attr_reader :name

  def read
    size = Dll.Read @server, 0, 0
    return nil if size == 0
    buffer = [].pack "x#{size}"
    size = Dll.Read @server, buffer, size
    if size != 0
      Marshal.load buffer rescue nil
    end
  end

  def write msg
    msg = Marshal.dump msg
    @client ||= Dll.Open SLOT_GAME
    written = Dll.Write @client, msg, msg.bytesize
    if written == 0
      @client = Dll.Open SLOT_GAME
      if invalid? @client
        @client = nil
        return false
      end
      written = Dll.Write @client, msg, msg.bytesize
    end
    written != 0
  end

  def dispose
    Dll.Close @server
    Dll.Close @client if @client and not invalid? @client
  end

  def create_server name
    handle = Dll.Create name
    if invalid? handle
      puts "Invalid handle: failed to create mailslot server."
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

SlotServer = Mailslot.new
