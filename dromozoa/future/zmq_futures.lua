-- Copyright (C) 2017 Tomoyuki Fujimori <moyu@dromozoa.com>
--
-- This file is part of dromozoa-future.
--
-- dromozoa-future is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- dromozoa-future is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with dromozoa-future.  If not, see <http://www.gnu.org/licenses/>.

local uint32 = require "dromozoa.commons.uint32"
local unix = require "dromozoa.unix"
local zmq = require "dromozoa.zmq"

local class = {}

function class.zmq_msg_recv(service, msg, socket)
  return service:deferred(function (promise)
    local result, message, code = msg:recv(socket, zmq.ZMQ_DONTWAIT)
    if result then
      return promise:set(result)
    elseif code == unix.EAGAIN then
      local future = service:io_handler(socket, "read", function (promise)
        while true do
          local result, message, code = msg:recv(socket, zmq.ZMQ_DONTWAIT)
          if result then
            return promise:set(result)
          elseif code == unix.EAGAIN then
            promise = coroutine.yield()
          else
            return promise:set(nil, message, code)
          end
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(nil, message, code)
    end
  end)
end

function class.zmq_msg_send(service, msg, socket, flags)
  if flags == nil then
    flags = zmq.ZMQ_DONTWAIT
  else
    flags = uint32.bor(flags, zmq.ZMQ_DONTWAIT)
  end
  return service:deferred(function (promise)
    local result, message, code = msg:send(socket, flags)
    if result then
      return promise:set(result)
    elseif code == unix.EAGAIN then
      local future = service:io_handler(socket, "write", function (promise)
        while true do
          local result, message, code = msg:send(socket, flags)
          if result then
            return promise:set(result)
          elseif code == unix.EAGAIN then
            promise = coroutine.yield()
          else
            return promise:set(nil, message, code)
          end
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(nil, message, code)
    end
  end)
end

return class
