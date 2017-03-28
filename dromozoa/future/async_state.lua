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

local pack = require "dromozoa.commons.pack"
local unpack = require "dromozoa.commons.unpack"
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, task)
  local self = super.new(service)
  self.task = task
  return self
end

function class:launch()
  super.launch(self)
  local task = self.task
  self.task = nil
  assert(self.service:add_task(task, coroutine.create(function (task)
    if self:is_running() then
      self:set(task:result())
    else
      self.result = pack(task:result())
    end
  end)))
end

function class:resume()
  super.resume(self)
  local result = self.result
  self.result = nil
  if result then
    self:set(unpack(result, 1, result.n))
  end
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, task)
    return setmetatable(class.new(service, task), class.metatable)
  end;
})
