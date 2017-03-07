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

function class.zmq_recv(service, socket)
  return service:deferred(function (promise)
    local msg = zmq.message()
    local result, message, code = msg:recv(socket, zmq.ZMQ_DONTWAIT)
    if result then
      return promise:set(msg)
    elseif code ~= unix.EAGAIN then
      return promise:set(nil, message, code)
    end
    local fd, message, code = socket:getsockopt(zmq.ZMQ_FD)
    if fd == nil then
      return promise:set(nil, message, code)
    end
    local future = service:io_handler(fd, "read", function (promise)
      while true do
        local events, message, code = socket:getsockopt(zmq.ZMQ_EVENTS)
        if events == nil then
          return promise:set(nil, message, code)
        end
        if uint32.band(events, zmq.ZMQ_POLLIN) ~= 0 then
          local result, message, code = msg:recv(socket, zmq.ZMQ_DONTWAIT)
          if result then
            return promise:set(msg)
          elseif code ~= unix.EAGAIN then
            return promise:set(nil, message, code)
          end
        end
        promise = coroutine.yield()
      end
    end)
    return promise:set(future:get())
  end)
end

function class.zmq_send(service, socket, msg, flags)
  if type(msg) ~= "userdata" then
    msg = zmq.message(msg)
  end
  if flags == nil then
    flags = zmq.ZMQ_DONTWAIT
  else
    flags = uint32.bor(flags, zmq.ZMQ_DONTWAIT)
  end
  return service:deferred(function (promise)
    local result, message, code = msg:send(socket, flags)
    if result then
      return promise:set(result)
    elseif code ~= unix.EAGAIN then
      return promise:set(nil, message, code)
    end
    local fd, message, code = socket:getsockopt(zmq.ZMQ_FD)
    if fd == nil then
      return promise:set(nil, message, code)
    end
    local future = service:io_handler(fd, "read", function (promise)
      while true do
        local events, message, code = socket:getsockopt(zmq.ZMQ_EVENTS)
        if events == nil then
          return promise:set(nil, message, code)
        end
        if uint32.band(events, zmq.ZMQ_POLLOUT) ~= 0 then
          local result, message, code = msg:send(socket, flags)
          if result then
            return promise:set(msg)
          elseif code ~= unix.EAGAIN then
            return promise:set(nil, message, code)
          end
        end
        promise = coroutine.yield()
      end
    end)
    return promise:set(future:get())
  end)
end

return class
