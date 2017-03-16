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

local service = future_service()

local done
assert(service:dispatch(function (service)
  local fd1, fd2 = assert(unix.pipe())
  assert(fd1:ndelay_on())
  assert(fd2:ndelay_on())

  local t = 0.1

  local f = service:read(fd1, 16)
  local w = service:when_any_table({ f = f })

  assert(w:wait_for(t) == "timeout")
  assert(f:wait_for(t) == "timeout")
  assert(w:wait_for(t) == "timeout")
  fd2:write("x")
  assert(w:wait_for(t) == "ready")

  local f = service:read(fd1, 16)
  local w1 = service:when_any_table({ f = f })
  local w2 = service:when_any_table({ f = f })

  assert(w1:wait_for(t) == "timeout")
  assert(w2:wait_for(t) == "timeout")
  assert(w1:wait_for(t) == "timeout")
  assert(w2:wait_for(t) == "timeout")
  fd2:write("y")
  assert(w1:wait_for(t) == "ready")
  assert(w2:wait_for(t) == "ready")

  assert(fd1:close())
  assert(fd2:close())

  service:stop()
  done = true
end))
assert(done)
