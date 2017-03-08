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

local reader_buffer = require "dromozoa.future.reader_buffer"

local class = {}

function class.new(service, source)
  return {
    service = service;
    source = source;
    buffer = reader_buffer();
    buffer_size = 4096;
  }
end

function class:read(count)
  return self.service:deferred(function (promise)
    local source = self.source
    local buffer = self.buffer
    local buffer_size = self.buffer_size
    while true do
      local result = buffer:read(count)
      if result then
        return promise:set(result)
      end
      local result, message, code = source:read(buffer_size):get()
      if not result then
        return promise:set(nil, message, code)
      elseif result == "" then
        buffer:close()
      else
        buffer:write(result)
      end
    end
  end)
end

function class:read_some(count)
  return self.service:deferred(function (promise)
    return promise:set(self.buffer:read_some(count))
  end)
end

function class:read_any(count)
  return self.service:deferred(function (promise)
    local source = self.source
    local buffer = self.buffer
    local buffer_size = self.buffer_size
    while true do
      local result = buffer:read_some(count)
      if result ~= "" or self.buffer.closed then
        return promise:set(result)
      end
      local result, message, code = source:read(buffer_size):get()
      if not result then
        return promise:set(nil, message, code)
      elseif result == "" then
        buffer:close()
      else
        buffer:write(result)
      end
    end
  end)
end

function class:read_until(pattern)
  return self.service:deferred(function (promise)
    local source = self.source
    local buffer = self.buffer
    local buffer_size = self.buffer_size
    while true do
      local result, capture = buffer:read_until(pattern)
      if result then
        return promise:set(result, capture)
      end
      local result, message, code = source:read(buffer_size):get()
      if not result then
        return promise:set(nil, message, code)
      elseif result == "" then
        buffer:close()
      else
        buffer:write(result)
      end
    end
  end)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service, source)
    return setmetatable(class.new(service, source), class.metatable)
  end;
})
