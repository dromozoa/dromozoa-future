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
local unpack = require "dromozoa.commons.unpack"

local function propagate(self)
  assert(self.state:is_ready())
  for share_state in self.share_states:each() do
    assert(share_state:is_running() or share_state:is_suspended() or share_state:is_ready())
    if share_state:is_running() then
      share_state:set(unpack(self.state.value, 1, self.state.value.n))
    end
  end
end

local class = {}

function class.new(service, state)
  local self = {
    service = service;
    state = state;
    share_states = sequence();
  }
  self.propagator = coroutine.create(function ()
    propagate(self)
  end)
  return self
end

function class:is_ready()
  return self.state:is_ready()
end

function class:launch(share_state)
  self.share_states:push(share_state)
  if self.state:is_ready() then
    propagate(self)
  elseif self.state:is_initial() or self.state:is_suspended() then
    local current_state = self.service:get_current_state()
    self.service:set_current_state(nil)
    if self.state:dispatch() then
      propagate(self)
    else
      self.state.caller = self.propagator
    end
    self.service:set_current_state(current_state)
  end
end

function class:suspend()
  assert(self.state:is_running() or self.state:is_ready())
  if self.state:is_running() then
    local is_running = false
    for share_state in self.share_states:each() do
      assert(share_state:is_running() or share_state:is_suspended())
      if share_state:is_running() then
        is_running = true
        break
      end
    end
    if not is_running then
      self.state:suspend()
    end
  end
end

function class:resume()
  assert(self.state:is_running() or self.state:is_suspended() or self.state:is_ready())
  if self.state:is_ready() then
    propagate(self)
  elseif self.state:is_suspended() then
    self.state:resume()
  end
end

local metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service, state)
    return setmetatable(class.new(service, state), metatable)
  end;
})
