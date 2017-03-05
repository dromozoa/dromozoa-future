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
local async_state = require "dromozoa.future.async_state"
local future = require "dromozoa.future.future"

local class = {}

function class.getaddrinfo(service, nodename, servname, hints)
  return future(async_state(service, unix.async_getaddrinfo(nodename, servname, hints)))
end

function class.getnameinfo(service, address, flags)
  return future(async_state(service, address:async_getnameinfo(flags)))
end

function class.nanosleep(service, tv1)
  return future(async_state(service, unix.async_nanosleep(tv1)))
end

return class
