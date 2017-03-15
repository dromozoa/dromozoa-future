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

local dumper = require "dromozoa.commons.dumper"
local pairs = require "dromozoa.commons.pairs"
local sequence = require "dromozoa.commons.sequence"
local uint32 = require "dromozoa.commons.uint32"
local unpack = require "dromozoa.commons.unpack"
local dyld = require "dromozoa.dyld"
local unix = require "dromozoa.unix"
local future_service = require "dromozoa.future.future_service"

local symbol = dyld.RTLD_DEFAULT:dlsym("pthread_create")
if not symbol or symbol:is_null() then
  dyld.dlopen("libpthread.so.0", uint32.bor(dyld.RTLD_LAZY, dyld.RTLD_GLOBAL))
end

local service = future_service()

assert(service:dispatch(function (service)
  local f = service:nanosleep(1.5)
  f:wait_for(0.5)
  f:wait_for(0.5)
  assert(f:get())

  local f = service:nanosleep(1.5)
  f:wait_for(0.5)
  unix.nanosleep(1)
  assert(f:get())

  local f1 = service:getaddrinfo("github.com", "https")
  local f2 = service:getaddrinfo("luarocks.org", "https")
  local f3 = service:getaddrinfo("www.lua.org", "https")
  local f4 = service:getaddrinfo("www.google.com", "https")
  local f5 = service:getaddrinfo("test-ipv6.com", "https")

  local futures = {
    f1 = f1,
    f2 = f2;
    f3 = f3;
    f4 = f4;
    f5 = f5;
  }

  local addrinfo = sequence()

  local f = service:when_any(f1, f2, f3, f4, f5)
  print("when_any", f.state)
  f:get()
  for key, future in pairs(futures) do
    if future:is_ready() then
      futures[key] = nil
      print(key)
      -- addrinfo:push(unpack(future:get()))
    end
  end

  local f = service:when_any_table(futures)
  print("when_any_table", f.state)
  local key, f = f:get()
  print(key, f)
  -- addrinfo:push(unpack(futures[key]:get()))
  futures[key] = nil

  print("--1")
  addrinfo:push(unpack(assert(f1:get())))
  print("--2")
  addrinfo:push(unpack(assert(f2:get())))
  print("--3")
  addrinfo:push(unpack(assert(f3:get())))
  print("--4")
  addrinfo:push(unpack(assert(f4:get())))
  print("--5")
  addrinfo:push(unpack(assert(f5:get())))
  print("--6")
  -- print(dumper.encode(addrinfo, { pretty = true }))

  service:stop()
end))
