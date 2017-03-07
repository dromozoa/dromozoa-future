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

local zmq = require "dromozoa.zmq"
local create_thread = require "dromozoa.future.create_thread"
local resume_thread = require "dromozoa.future.resume_thread"

local class = {}

function class.new(fd, event, thread)
  return {
    fd = fd;
    event = event;
    thread = create_thread(thread);
  }
end

function class:dispatch(service, event)
  resume_thread(self.thread, service, self, event)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, fd, event, thread)
    return setmetatable(class.new(fd, event, thread), class.metatable)
  end;
})
