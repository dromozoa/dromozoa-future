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

local future_service = require "dromozoa.future.future_service"

future_service():dispatch(function (service)
  local f = service:deferred(function (promise)
    local f = function ()
      promise:error("foo")
    end
    f()
    error("unreachable")
  end)

  local result, message = f:get()
  assert(not result)
  assert(message)

  service:stop()
end)

local thread = coroutine.create(function ()
  local f = function ()
    error("foo")
  end
  f()
end)
print(coroutine.resume(thread))
