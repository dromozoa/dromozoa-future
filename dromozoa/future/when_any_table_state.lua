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

local pairs = require "dromozoa.commons.pairs"
local state = require "dromozoa.future.state"

local function each_state(self)
  return coroutine.wrap(function ()
    for key, future in pairs(self.futures) do
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
      self:set(key)
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
  for key, that in each_state(self) do
    service:set_current_state(nil)
    if that:dispatch() then
      if count_down(self, key) then
        break
      end
    else
      that.caller = coroutine.create(function ()
        if not count_down(self, key) then
          coroutine.yield()
        end
      end)
    end
  end
  service:set_current_state(current_state)
end

local function suspend(self)
  for _, that in each_state(self) do
    if that:is_running() then
      that:suspend()
      that.caller = nil
    end
  end
end

local super = state
local class = {}

function class.new(service, futures)
  local self = state.new(service)
  self.futures = futures
  self.count = 1
  self.counted = {}
  return self
end

function class:launch()
  state.launch(self)
  dispatch(self)
end

function class:suspend()
  state.suspend(self)
  suspend(self)
end

function class:resume()
  state.resume(self)
  dispatch(self)
end

function class:finish()
  state.finish(self)
  suspend(self)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, futures)
    return setmetatable(class.new(service, futures), class.metatable)
  end;
})
