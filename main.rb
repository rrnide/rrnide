# encoding: utf-8
require 'json'

require 'midori'
require 'mimemagic'

require_relative 'lib/mailslot'
require_relative 'lib/plugin'

MESSAGE_QUEUE = []
CLIENTS = []
UID = Hash.new { |hash, key| hash[key] = 0 }

class << EventLoop
  old = instance_method :run_once
  define_method :run_once do
    old.bind(self).call
    unless MESSAGE_QUEUE.empty?
      MESSAGE_QUEUE.delete_if do |msg|
        SlotServer.write msg
      end
    end
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

  get '/plugins' do
    @header['Content-Type'] = 'application/json'
    JSON.generate PluginManager.plugins
  end

  post '/install' do
    @header['Content-Type'] = 'application/json'
    file, proj = JSON.parse request.body
    PluginManager.install file, proj
    JSON.generate true
  rescue
    JSON.generate false
  end

  post '/uninstall' do
    @header['Content-Type'] = 'application/json'
    file, proj = JSON.parse request.body
    PluginManager.uninstall file, proj
    JSON.generate true
  rescue
    JSON.generate false
  end

  post '/eval' do
    @header['Content-Type'] = 'application/json'
    unless SlotServer.eval request.body, UID[:eval] += 1
      MESSAGE_QUEUE << [:eval, request.body, UID[:eval]]
    end
    JSON.generate UID[:eval]
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
