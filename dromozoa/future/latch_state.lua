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

local ipairs = require "dromozoa.commons.ipairs"
local pack = require "dromozoa.commons.pack"
local unpack = require "dromozoa.commons.unpack"
local state = require "dromozoa.future.state"

local function each_state(self)
  return coroutine.wrap(function ()
    for key, future in ipairs(self.futures) do
      coroutine.yield(key, future.state)
    end
  end)
end

local function count_down(self, key)
  local counted = self.counted
  if counted[key] == nil then
    counted[key] = true
    local count = self.count - 1
    self.count = count
    if count == 0 then
      local futures = self.futures
      self:set(unpack(futures, 1, futures.n))
      self.futures = nil
      self.count = nil
      self.counted = nil
      return true
    end
  end
  return false
end

local function dispatch(self)
  local service = self.service
  local current_state = service:get_current_state()
  for key, state in each_state(self) do
    service:set_current_state(nil)
    if state:dispatch() then
      if count_down(self, key) then
        break
      end
    else
      state.caller = coroutine.create(function ()
        if not count_down(self, key) then
          coroutine.yield()
        end
      end)
    end
  end
  service:set_current_state(current_state)
end

local function suspend(self)
  for _, state in each_state(self) do
    if state:is_running() then
      state:suspend()
      state.caller = nil
    end
  end
end

local super = state
local class = {}

function class.new(service, count, ...)
  local self = super.new(service)
  local futures = pack(...)
  self.futures = futures
  if count == "n" then
    self.count = futures.n
  else
    self.count = count
  end
  self.counted = {}
  return self
end

function class:launch()
  super.launch(self)
  dispatch(self)
end

function class:suspend()
  super.suspend(self)
  suspend(self)
end

function class:resume()
  super.resume(self)
  dispatch(self)
end

function class:finish()
  super.finish(self)
  suspend(self)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, count, ...)
    return setmetatable(class.new(service, count, ...), class.metatable)
  end;
})
