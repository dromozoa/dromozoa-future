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

local sequence = require "dromozoa.commons.sequence"
local uint32 = require "dromozoa.commons.uint32"
local unix = require "dromozoa.unix"
local zmq = require "dromozoa.zmq"

local function find_poller_item(self, socket, fd)
  for i, poller_item in ipairs(self.poller_items) do
    if poller_item.socket == socket and poller_item.fd == fd then
      return i, poller_item
    end
  end
end

local class = {}

function class.new()
  return {
    poller_timeout = 20;
    poller_items = sequence();
  }
end

function class:add_handler(handler)
  local socket = handler.socket
  local fd
  if socket == nil then
    fd = unix.fd.get(handler.fd)
  end
  local _, poller_item = find_poller_item(self, socket, fd)
  if poller_item == nil then
    poller_item = {
      socket = socket;
      fd = fd;
      events = 0;
    }
    self.poller_items:push(poller_item)
  end
  local event = handler.event
  if event == "read" then
    assert(uint32.band(poller_item.events, zmq.ZMQ_POLLIN) == 0)
    assert(poller_item.read_handler == nil)
    poller_item.events = uint32.bor(poller_item.events, zmq.ZMQ_POLLIN)
    poller_item.read_handler = handler
    return self
  elseif event == "write" then
    assert(uint32.band(poller_item.events, zmq.ZMQ_POLLOUT) == 0)
    assert(poller_item.write_handler == nil)
    poller_item.events = uint32.bor(poller_item.events, zmq.ZMQ_POLLOUT)
    poller_item.write_handler = handler
    return self
  end
end

function class:remove_handler(handler)
  local socket = handler.socket
  local fd
  if socket == nil then
    fd = unix.fd.get(handler.fd)
  end
  local i = find_poller_item(self, socket, fd)
  if i ~= nil then
    table.remove(self.poller_items, i)
    return self
  end
end

function class:dispatch()
  local poller_items = self.poller_items
  local result, message, code = zmq.poll(poller_items, self.poller_timeout)
  if not result then
    if code ~= unix.EINTR then
      return result, message, code
    end
  else
    for poller_item in poller_items:each() do
      local revents = poller_item.revents
      if uint32.band(revents, zmq.ZMQ_POLLIN) ~= 0 then
        poller_item.read_handler:dispatch(self, "read")
      end
      if uint32.band(revents, zmq.ZMQ_POLLOUT) ~= 0 then
        poller_item.write_handler:dispatch(self, "write")
      end
    end
  end
  return self
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function ()
    return setmetatable(class.new(), class.metatable)
  end;
})
