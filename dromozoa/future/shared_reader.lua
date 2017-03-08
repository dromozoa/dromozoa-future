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

local reader = require "dromozoa.future.reader"

local class = {}

function class.new(service, fd)
  return {
    service = service;
    fd = fd;
  }
end

function class:read(size)
  local shared_future = self.shared_future
  if shared_future == nil or shared_future:is_ready() then
    local service = self.service
    shared_future = service:make_shared_future(service:read(self.fd, size))
    self.shared_future = shared_future
  end
  return shared_future:share()
end

function class:share()
  return reader(self.service, self)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service, fd)
    return setmetatable(class.new(service, fd), class.metatable)
  end;
})
