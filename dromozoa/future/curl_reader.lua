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

function class.new(service, state, event)
  return {
    service = service;
    state = state;
    event = event;
    buffer = reader_buffer();
  }
end

class.metatable = {
  __index = class;
}

function class:write(data)
  self.buffer:write(data)
  local thread = self.thread
  self.thread = nil
  if thread ~= nil then
    resume_thread(thread)
  end
end

function class:close()
  self.buffer:close()
  local thread = self.thread
  self.thread = nil
  if thread ~= nil then
    resume_thread(thread)
  end
end

function class:read(count)
  return self.service:deferred(function (promise)
    local event = self.event
    local buffer = self.buffer

    local result = buffer:read(count)
    if result then
      return promise:set(result)
    end
    while true do
      local f = future(curl_reader_state(self.service, self))
      print("!f:get", coroutine.running())
      f:get()
      print("!f:get done")
      local result = buffer:read(count)
      print("!f:get result", result)
      if result then
        return promise:set(result)
      end
    end
  end)
end

return setmetatable(class, {
  __call = function (_, service, state, event)
    return setmetatable(class.new(service, state, event), class.metatable)
  end;
})
