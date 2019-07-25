require 'midori.rb'
require 'mimemagic'
require 'json'
require_relative 'mailslot'

def is_valid_ruby?(text)
  catch(:out) { eval "BEGIN { throw :out }; #{text}" }
  true
rescue SyntaxError
  false
end

class AppRoute < Midori::API
  capture Errno::ENOENT do |e|
    @status = 404
    "Not found"
  end

  post '/console/eval' do
    @header['Content-Type'] = 'application/json'
    text = request.body
    JSON.generate(is_valid_ruby?(text) ? RrnideServer.write(text) : '..')
  end

  post '/console/poll' do
    @header['Content-Type'] = 'application/json'
    JSON.generate(ret: RrnideServer.read&.force_encoding('utf-8'))
  end

  get '*' do
    file_path = File.join 'frontend', request.params['splat']
    file_path = 'frontend/index.html' if file_path == 'frontend/'
    raise Errno::ENOENT if File.directory? file_path
    Midori::Response.new(status: 200,
                         header: { 'Content-Type': MimeMagic.by_path(file_path) },
                         body: File.read(file_path))
  end
end

begin
  Midori::Runner.new(AppRoute).start
rescue Interrupt
  puts "See you next time."
rescue => e
  puts "#{e.class}: #{e}", e.backtrace
  retry
end
