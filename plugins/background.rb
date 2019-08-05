# @display 后台运行
# @help Rrnide 必备
# @id background_running
# @author SixRC
if Graphics.respond_to? :background_exec=
  Graphics.background_exec = true
else
  module Kernel
    GetWindowThreadProcessId = Win32API.new("user32", "GetWindowThreadProcessId", "LP", "L")
    GetWindow = Win32API.new("user32", "GetWindow", "LL", "L")
    GetClassName = Win32API.new("user32", "GetClassName", "LPL", "L")
    GetCurrentThreadId = Win32API.new("kernel32", "GetCurrentThreadId", "V", "L")
    GetForegroundWindow = Win32API.new("user32", "GetForegroundWindow", "V", "L")

    def hwnd
      threadID = GetCurrentThreadId.call
      hWnd = GetWindow.call(GetForegroundWindow.call, 0)
      while hWnd != 0
        if threadID == GetWindowThreadProcessId.call(hWnd, 0)
          className = " " * 12
          GetClassName.call(hWnd, className, 12)
          break if className[0, 11] == "RGSS Player"
        end
        hWnd = GetWindow.call(hWnd, 2)
      end
      return hWnd
    end
  end

  HWND = hwnd

  module BackgroundRunning
    module_function

    GetActiveWindow = Win32API.new('user32', 'GetActiveWindow', 'v', 'L')
    GetProcAddress = Win32API.new('kernel32', 'GetProcAddress', 'Lp', 'L')
    LoadLibrary = Win32API.new('kernel32', 'LoadLibraryA', 'p', 'L')
    User32 = LoadLibrary.call('user32')
    GetAsyncKeyState = GetProcAddress.call(User32, 'GetAsyncKeyState')
    GetKeyState = GetProcAddress.call(User32, 'GetKeyState')
    WriteProcessMemory = Win32API.new('kernel32', 'WriteProcessMemory', 'LLpLL', 'L')
    ReadProcessMemory = Win32API.new('kernel32', 'ReadProcessMemory', 'LLpLL', 'L')
    
    @original = [].pack('x5')
    @original_va = [].pack('x5')
    @mask = "\x31\xC0\xC2\x04\x00"
    ReadProcessMemory.call(-1, GetAsyncKeyState, @original, 5, 0)
    ReadProcessMemory.call(-1, GetKeyState, @original_va, 5, 0)

    @state = false

    def update
      if !@state and HWND != GetActiveWindow.call
        WriteProcessMemory.call(-1, GetAsyncKeyState, @mask, 5, 0)
        WriteProcessMemory.call(-1, GetKeyState, @mask, 5, 0)
        return @state = true
      elsif @state and HWND == GetActiveWindow.call
        WriteProcessMemory.call(-1, GetAsyncKeyState, @original, 5, 0)
        WriteProcessMemory.call(-1, GetKeyState, @original_va, 5, 0)
        return @state = false
      end
    end

    DLL = LoadLibrary.call('RGSS301')

    @active = false

    def active=(x)
      if @active = x
        WriteProcessMemory.call(-1, DLL + 0x2712, "\0", 1, 0)
      else
        WriteProcessMemory.call(-1, DLL + 0x2712, "\x5A", 1, 0)
      end
    end

    def activate
      self.active = true
    end

    def deactivate
      self.active = false
    end

    singleton_class.class_eval { attr_reader :state, :active }
  end

  class << ::Input
    alias _update_without_background_running update
    def update
      BackgroundRunning.update
      _update_without_background_running
    end
  end

  BackgroundRunning.activate
end
