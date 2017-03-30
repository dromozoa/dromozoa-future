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

local class = {}

function class.new()
  return {
    selector = unix.selector();
    selector_timeout = unix.timespec({ tv_sec = 0, tv_nsec = 100000000 }, unix.TIMESPEC_TYPE_DURATION);
    read_handlers = {};
    write_handlers = {};
  }
end

function class:add_handler(handler)
  local fd = unix.fd.get(handler.fd)
  local event = handler.event
  if event == "read" then
    local read_handlers = self.read_handlers
    assert(read_handlers[fd] == nil)
    if self.write_handlers[fd] == nil then
      if not self.selector:add(fd, unix.SELECTOR_READ) then
        return unix.get_last_error()
      end
    else
      if not self.selector:mod(fd, unix.SELECTOR_READ_WRITE) then
        return unix.get_last_error()
      end
    end
    read_handlers[fd] = handler
    return self
  elseif event == "write" then
    local write_handlers = self.write_handlers
    assert(write_handlers[fd] == nil)
    if self.read_handlers[fd] == nil then
      if not self.selector:add(fd, unix.SELECTOR_WRITE) then
        return unix.get_last_error()
      end
    else
      if not self.selector:mod(fd, unix.SELECTOR_READ_WRITE) then
        return unix.get_last_error()
      end
    end
    write_handlers[fd] = handler
    return self
  end
end

function class:remove_handler(handler)
  local fd = unix.fd.get(handler.fd)
  local event = handler.event
  if event == "read" then
    local read_handlers = self.read_handlers
    assert(read_handlers[fd] ~= nil)
    if self.write_handlers[fd] == nil then
      if not self.selector:del(fd) then
        return unix.get_last_error()
      end
    else
      if not self.selector:mod(fd, unix.SELECTOR_WRITE) then
        return unix.get_last_error()
      end
    end
    read_handlers[fd] = nil
    return self
  elseif event == "write" then
    local write_handlers = self.write_handlers
    assert(write_handlers[fd] ~= nil)
    if self.read_handlers[fd] == nil then
      if not self.selector:del(fd) then
        return unix.get_last_error()
      end
    else
      if not self.selector:mod(fd, unix.SELECTOR_READ) then
        return unix.get_last_error()
      end
    end
    write_handlers[fd] = nil
    return self
  end
end

function class:dispatch()
  local selector = self.selector
  local result = selector:select(self.selector_timeout)
  if not result then
    if unix.get_last_errno() ~= unix.EINTR then
      return unix.get_last_error()
    end
  else
    local read_handlers = self.read_handlers
    local write_handlers = self.write_handlers
    for i = 1, result do
      local fd, event = selector:event(i)
      if uint32.band(event, unix.SELECTOR_READ) ~= 0 then
        read_handlers[fd]:dispatch("read")
      end
      if uint32.band(event, unix.SELECTOR_WRITE) ~= 0 then
        write_handlers[fd]:dispatch("write")
      end
    end
  end
  return self
end

function class:get_handlers(fd)
  local fd = unix.fd.get(fd)
  return self.read_handlers[fd], self.write_handlers[fd]
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function ()
    return setmetatable(class.new(), class.metatable)
  end;
})
