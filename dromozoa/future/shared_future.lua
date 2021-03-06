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

local future = require "dromozoa.future.future"
local share_state = require "dromozoa.future.share_state"

local class = {}

function class.new(service, shared_state)
  return {
    service = service;
    shared_state = shared_state;
  }
end

function class:is_ready()
  return self.shared_state:is_ready()
end

function class:share()
  return future(share_state(self.service, self.shared_state))
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service, shared_state)
    return setmetatable(class.new(service, shared_state), class.metatable)
  end;
})
