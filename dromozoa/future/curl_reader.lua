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

local curl_reader_state = require "dromozoa.future.curl_reader_state"
local future = require "dromozoa.future.future"
local reader_buffer = require "dromozoa.future.reader_buffer"
local resume_thread = require "dromozoa.future.resume_thread"

local class = {}

function class.new(service, state)
  return {
    service = service;
    state = state;
    buffer = reader_buffer();
  }
end

function class:write(data)
  self.buffer:write(data)
  local thread = self.thread
  self.thread = nil
  if thread ~= nil then
    resume_thread(thread, "write")
  end
end

function class:close()
  self.buffer:close()
  local thread = self.thread
  self.thread = nil
  if thread ~= nil then
    resume_thread(thread, "close")
  end
end

function class:read(count)
  return self.service:deferred(function (promise)
    self.state:start()
    local buffer = self.buffer
    while true do
      local result = buffer:read(count)
      if result then
        return promise:set(result)
      end
      future(curl_reader_state(self.service, self)):get()
    end
  end)
end

function class:read_some(count)
  return self.service:deferred(function (promise)
    self.state:start()
    return promise:set(self.buffer:read_some(count))
  end)
end

function class:read_any(count)
  return self.service:deferred(function (promise)
    self.state:start()
    local buffer = self.buffer
    while true do
      local result = buffer:read_some(count)
      if result ~= "" or buffer.closed then
        return promise:set(result)
      end
      future(curl_reader_state(self.service, self)):get()
    end
  end)
end

function class:read_until(pattern)
  return self.service:deferred(function (promise)
    self.state:start()
    local buffer = self.buffer
    while true do
      local result, capture = buffer:read_until(pattern)
      if result then
        return promise:set(result, capture)
      end
      future(curl_reader_state(self.service, self)):get()
    end
  end)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service, state)
    return setmetatable(class.new(service, state), class.metatable)
  end;
})
