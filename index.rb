require "sinatra"
require "sinatra/reloader" if development?

set bind: '0.0.0.0',
    public_folder: '.'

get "/" do
  redirect '/index.html'
end

post "/" do
  eval(request.body.read, TOPLEVEL_BINDING).inspect
end
