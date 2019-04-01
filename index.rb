GameRoot, = ARGV

if !GameRoot || !(File.exist? File.join GameRoot, 'Game.exe')
  puts "ruby #$0 path/to/your/game/folder"
  exit
end

GameRoot = GameRoot.tr('\\', '/')

require "sinatra"
require "sinatra/async" # gem install eventmachine --platform ruby

register Sinatra::Async

set bind: '0.0.0.0',
    public_folder: '.'

enable :show_exceptions

get "/" do
  redirect '/index.html'
end

require "json"
post "/" do
  redirect '/run/a', 307
end

apost '/run/:x' do |x|
  infile = File.join(GameRoot, "Scripts/run/#{x}.i")
  outfile = %w'o e'.map { |e| File.join GameRoot, "Scripts/run/#{x}.#{e}" }
  outfile.each { |f| File.delete f if File.exist? f }
  open infile, 'w' do |f|
    f.write request.body.read
  end
  timer = EM.add_periodic_timer 0.1 do
    if !(File.exist? infile) && outfile.any? { |f| File.exist? f }
      payload = {}
      outfile.each do |e|
        if File.exist?(e) && File.size(e) > 0
          payload[e[-1]] = File.read(e).force_encoding(Encoding::UTF_8)
        end
      end
      if !payload.empty?
        body JSON.generate(payload)
        timer.cancel
      end
    end
  end
end
