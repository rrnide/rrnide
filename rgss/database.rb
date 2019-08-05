
module Database
  LOAD_JSON = <<-EOF
    require 'json'
    data = Marshal.dump JSON.parse File.read <%= file.inspect %>
    print [data].pack('m0')
  EOF

  LOAD_YAML = <<-EOF
    require 'psych'
    data = Marshal.dump Psych.load_file <%= file.inspect %>
    print [data].pack('m0')
  EOF

  LOAD_CSV = <<-EOF
    require 'csv'
    data = Marshal.dump CSV.table <%= file.inspect %>
    print [data].pack('m0')
  EOF

  module_function

  def self.tmpname
    "#{Time.now.strftime("%Y%m%d")}-#{$$}-#{rand(0x100000000).to_s(36)}.rb"
  end

  def self.ruby code, binding
    filename = tmpname
    code = code.gsub(/<%= (.+?) %>/) { binding.eval $1 }
    open(filename, 'w') { |f| f.write code }
    ret = Marshal.load `ruby #{filename.inspect}`.unpack('m0')[0]
    File.delete filename
    ret
  end

  def self.load file, ext=File.extname(file)
    env = binding
    case ext.downcase
    when '.rb'
      eval File.read(file), TOPLEVEL_BINDING.dup
    when '.json'
      ruby LOAD_JSON, env
    when '.yaml'
      ruby LOAD_YAML, env
    when '.csv'
      ruby LOAD_CSV, env
    else
      File.read(file)
    end
  end
end
