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
local zmq = require "dromozoa.zmq"

local fd1, fd2 = assert(unix.pipe())

assert(getmetatable(fd1).__index == unix.fd)
assert(getmetatable(fd1) == debug.getregistry()["dromozoa.unix.fd"])

assert(fd1:close())
assert(fd2:close())

local ctx = assert(zmq.context())

local socket1 = assert(ctx:socket(zmq.ZMQ_REP))
assert(socket1:bind("tcp://127.0.0.1:5555"))
local socket2 = assert(ctx:socket(zmq.ZMQ_REP))
assert(socket2:bind("tcp://127.0.0.1:5556"))

assert(getmetatable(socket1).__index == zmq.socket)
assert(getmetatable(socket1) == debug.getregistry()["dromozoa.zmq.socket"])
assert(getmetatable(socket2).__index == zmq.socket)
assert(getmetatable(socket2) == debug.getregistry()["dromozoa.zmq.socket"])

print(tostring(socket1), tostring(socket2))
assert(socket1 == socket1)
assert(socket1 ~= socket2)

assert(socket1:close())
assert(socket2:close())
assert(ctx:term())
