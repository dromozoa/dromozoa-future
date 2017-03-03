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

local function count_down(self, key)
  local count = self.count
  local counted = self.counted
  -- print("counted", counted, key)
  if not counted[key] then
    counted[key] = true
    count = count - 1
  end
  -- count = count - 1
  self.count = count
  if count == 0 then
    local futures = self.futures
    self:set(unpack(futures, 1, futures.n))
    return true
  else
    return false
  end
end

local function each_state(self)
  return coroutine.wrap(function ()
    for key, future in ipairs(self.futures) do
      coroutine.yield(key, future.state)
    end
  end)
end

local super = state
local class = {}

function class.new(service, count, ...)
  local self = state.new(service)
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
  state.launch(self)
  local service = self.service
  local current_state = service:get_current_state()
  for key, that in each_state(self) do
    assert(that:is_initial() or that:is_suspended() or that:is_ready())
    service:set_current_state(nil)
    if that:dispatch() then
      if count_down(self, key) then
        break
      end
    else
      that.caller = coroutine.create(function ()
        while true do
          if count_down(self, key) then
            break
          end
          coroutine.yield()
        end
      end)
    end
  end
  service:set_current_state(current_state)
end

function class:suspend()
  state.suspend(self)
  for key, that in each_state(self) do
    assert(that:is_running() or that:is_ready())
    if that:is_running() then
      that:suspend()
    end
  end
end

function class:resume()
  state.resume(self)
  local service = self.service
  local current_state = service:get_current_state()
  for key, that in each_state(self) do
    assert(that:is_initial() or that:is_suspended() or that:is_ready())
    service:set_current_state(nil)
    if that:dispatch() then
      if count_down(self, key) then
        break
      end
    else
      that.caller = coroutine.create(function ()
        while true do
          if count_down(self, key) then
            break
          end
          coroutine.yield()
        end
      end)
    end
  end
  service:set_current_state(current_state)
end

function class:finish()
  state.finish(self)
  for key, that in each_state(self) do
    if that:is_running() then
      that:suspend()
    end
    that.caller = nil
  end
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
