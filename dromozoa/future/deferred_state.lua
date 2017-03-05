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

local create_thread = require "dromozoa.future.create_thread"
local promise = require "dromozoa.future.promise"
local resume_thread = require "dromozoa.future.resume_thread"
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, thread)
  local self = super.new(service)
  local thread = create_thread(thread)
  self.deferred = coroutine.create(function ()
    resume_thread(thread, promise(self))
  end)
  return self
end

function class:launch()
  super.launch(self)
  local deferred = self.deferred
  self.deferred = nil
  resume_thread(deferred)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, thread)
    return setmetatable(class.new(service, thread), class.metatable)
  end;
})
