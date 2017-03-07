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
local io_handler = require "dromozoa.future.io_handler"
local promise = require "dromozoa.future.promise"
local resume_thread = require "dromozoa.future.resume_thread"
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, fd, event, thread)
  local self = super.new(service)
  local thread = create_thread(thread)
  self.handler = io_handler(fd, event, coroutine.create(function ()
    local promise = promise(self)
    while true do
      resume_thread(thread, promise)
      if self:is_ready() then
        return
      end
      coroutine.yield()
    end
  end))
  return self
end

function class:launch()
  super.launch(self)
  assert(self.service:add_handler(self.handler))
end

function class:suspend()
  super.suspend(self)
  assert(self.service:remove_handler(self.handler))
end

function class:resume()
  super.resume(self)
  assert(self.service:add_handler(self.handler))
end

function class:finish()
  super.finish(self)
  local handler = self.handler
  self.handler = nil
  assert(self.service:remove_handler(handler))
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, fd, event, thread)
    return setmetatable(class.new(service, fd, event, thread), class.metatable)
  end;
})
