# coding: utf-8
# this file has two parts,
#   the upper one run in game.exe,
#   the lower one run by rgss.exe
if defined? Graphics
  # loop(check_pipe) { |got(msg)| new_thread { send_response(msg) } }
else
  # if (got(command)):
  #   new_thread:
  #     send_msg_to_pipe(msg_from(command))
  #     sleep until response = got_msg_from(pipe)
  #     send_res_to_user(response)
end
