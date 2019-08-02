# encoding: utf-8
require 'json'

require 'midori'
require 'mimemagic'

require_relative 'lib/mailslot'

MESSAGE_QUEUE = []
CLIENTS = []
UID = Hash.new { |hash, key| hash[key] = 0 }

class << EventLoop
  old = instance_method :run_once
  define_method :run_once do
    old.bind(self).call
    if msg = SlotServer.read
      CLIENTS.each do |ws|
        ws.send [(JSON.generate msg)].pack('m0')
      end
    end
  end
end

def check_syntax text
  catch(:out) { eval "BEGIN { throw :out }; #{text}" }
  true
rescue SyntaxError
  false
end

class AppRoute < Midori::API
  websocket '/' do |ws|
    ws.on :open do
      CLIENTS.push ws
    end

    ws.on :close do
      CLIENTS.delete ws
    end
  end

  capture Errno::ENOENT do
    Midori::Response.new status: 404,
                         body: 'Not found'
  end

  post '/eval' do
    @header['Content-Type'] = 'application/json'
    unless SlotServer.eval request.body, UID[:eval] += 1
      JSON.generate false
    else
      JSON.generate UID[:eval]
    end
  end

  post '/check' do
    @header['Content-Type'] = 'application/json'
    JSON.generate check_syntax request.body
  end

  get '*' do
    file_path = File.join 'frontend', request.params['splat']
    file_path += 'index.html' if file_path.end_with? '/'
    raise Errno::ENOENT if File.directory? file_path
    payload = {
      status: 200,
      header: { 'Content-Type': (MimeMagic.by_path file_path) },
      body: (IO.binread file_path)
    }
    Midori::Response.new **payload
  end
end

$server = Midori::Runner.new AppRoute

begin
  $server.start
rescue Interrupt
  puts 'see you next time'
  $server.stop
rescue => e
  puts "#{e.class}: #{e}", e.backtrace
  $server.stop
  retry
end
