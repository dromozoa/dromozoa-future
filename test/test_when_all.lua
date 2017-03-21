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

unix.ignore_signal(unix.SIGPIPE)

assert(future_service():dispatch(function (service)
  local fd1, fd2 = assert(unix.pipe())
  assert(fd1:ndelay_on())
  assert(fd2:ndelay_off())

  local shared_reader = service:make_shared_reader(fd1)

  local f1 = service:deferred(function (promise)
    local reader = shared_reader:share()
    print("f1")
    reader:read(1):get()
    print("f1 done")
    return promise:set(true)
  end)

  local f2 = service:deferred(function (promise)
    local reader = shared_reader:share()
    print("f2")
    reader:read(1):get()
    print("f2 done")
    return promise:set(true)
  end)

  service:when_all(f1, f2):wait_for(0.5)
  assert(fd2:write("x"))
  assert(fd2:close())

  print(f1:get())
  print(f2:get())

  assert(fd1:close())
  service:stop()
end))
