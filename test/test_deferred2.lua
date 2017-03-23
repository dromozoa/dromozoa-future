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

local unix = require "dromozoa.unix"
local future_service = require "dromozoa.future.future_service"

assert(future_service():dispatch(function (service)
  local fd1, fd2 = assert(unix.pipe())
  assert(fd1:ndelay_on())
  assert(fd2:ndelay_on())

  local f = service:deferred(function (promise)
    local f = service:deferred(function (promise)
      local f = service:deferred(function (promise)
        local f = service:deferred(function (promise)
          service:read(fd1, 1):get()
          promise:set(true)
        end)
        f:get()
        promise:set(true)
      end)
      f:get()
      promise:set(true)
    end)
    f:get()
    promise:set(true)
  end)

  f:wait_for(0.2)
  f:wait_for(0.2)
  assert(fd2:close())
  f:get()

  service:stop()
end))
