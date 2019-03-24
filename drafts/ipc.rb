# coding: utf-8
module IPC
  def self.basename
    File.join(ENV['TEMP'].tr('\\', '/'), 'rrnideipc')
  end

  def self.suffix
    defined?(::Graphics) ? 'io' : 'oi'
  end

  def self.fin
    "#{basename}.#{suffix[0]}"
  end

  File.delete fin if File.exist? fin

  def self.fout
    "#{basename}.#{suffix[1]}"
  end

  def self.async(&blk)
    @task = Thread.new { blk.call; @task = nil }
    @task.abort_on_exception = false
  end

  def self.running?
    !@task.nil? && @task.alive?
  end

  if defined? ::Graphics
    class << Graphics
      alias _rrnide_update update
      def update
        _rrnide_update
        if File.exist? IPC.fin and !IPC.running?
          IPC.async do
            ret = Kernel.eval(File.read(IPC.fin), TOPLEVEL_BINDING)
            open(IPC.fin, 'wb') { |f| Marshal.dump ret, f }
            File.rename IPC.fin, IPC.fout
          end
        end
      end
    end
  else
    def self.eval(str)
      open(IPC.fin, 'w') { |f| f.write str }
      File.rename IPC.fin, IPC.fout
      sleep 0.01 until File.exist? IPC.fin
      open(IPC.fin, 'rb') { |f| Marshal.load f }
    end

    def self.async_eval(str)
      async { eval(str).tap { |ret| yield ret if block_given? } }
    end
  end
end
