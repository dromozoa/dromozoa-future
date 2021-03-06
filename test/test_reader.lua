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

local uint32 = require "dromozoa.commons.uint32"
local unix = require "dromozoa.unix"
local future_service = require "dromozoa.future.future_service"

local fd1, fd2 = unix.socketpair(unix.AF_UNIX, uint32.bor(unix.SOCK_STREAM, unix.SOCK_CLOEXEC))
assert(fd1:ndelay_on())
assert(fd2:ndelay_off())

local service = future_service()

local done
assert(service:dispatch(function (service)
  local r = service:make_reader(fd1)

  local f = r:read_until("\n")
  assert(f:wait_for(0.2) == "timeout")
  fd2:write("foo")
  assert(f:wait_for(0.2) == "timeout")
  fd2:write("\nbar\n")
  assert(f:get() == "foo")
  local f = r:read_until("\n")
  assert(f:wait_for(0.2) == "ready")
  assert(f:get() == "bar")

  local f = r:read(3)
  fd2:write("a")
  assert(f:wait_for(0.2) == "timeout")
  fd2:write("b")
  assert(f:wait_for(0.2) == "timeout")
  fd2:write("c")
  assert(f:wait_for(0.2) == "ready")
  assert(f:get() == "abc")

  assert(r:read_some(3):get() == "")
  fd2:write("a")
  assert(r:read_some(3):get() == "")
  assert(r:read_any(3):get() == "a")
  fd2:write("abcdef")
  assert(r:read_any(3):get() == "abc")
  assert(r:read_some(3):get() == "def")

  service:stop()
  done = true
end))
assert(done)

assert(fd1:close())
assert(fd2:close())
