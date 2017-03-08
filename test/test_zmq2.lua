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

local zmq = require "dromozoa.zmq"
local future_service = require "dromozoa.future.future_service"

assert(future_service():dispatch(function (service)
  local ctx = assert(zmq.context())

  local f1 = service:deferred(function (promise)
    local socket = assert(ctx:socket(zmq.ZMQ_PUSH):bind("tcp://127.0.0.1:5555"))
    print("f1-send begin")
    assert(service:zmq_send(socket, 1):get())
    print("f1-send end")
    assert(socket:close())
    promise:set("f1")
  end)

  local f2 = service:deferred(function (promise)
    print("f2-wait begin")
    service:deferred(function () end):wait_for(1)
    print("f2-wait end")
    local socket = assert(ctx:socket(zmq.ZMQ_PULL):connect("tcp://127.0.0.1:5555"))
    print("f2-recv begin")
    local msg = promise:assert(service:zmq_recv(socket):get())
    print("f2-recv end", tostring(msg))
    assert(socket:close())
    promise:set("f2")
  end)

  service:when_all(f1, f2):get()
  assert(ctx:term())
  service:stop()
end))
