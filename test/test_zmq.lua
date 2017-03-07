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
  local rep = assert(ctx:socket(zmq.ZMQ_REP):bind("tcp://127.0.0.1:5555"))
  local req = assert(ctx:socket(zmq.ZMQ_REQ):connect("tcp://127.0.0.1:5555"))

  local f1 = service:deferred(function (promise)
    local msg = zmq.message("foo")
    promise:assert(service:zmq_msg_send(msg, req):get())
    print("f1-send", tostring(msg))
    local msg = zmq.message()
    promise:assert(service:zmq_msg_recv(msg, req):get())
    print("f1-recv", tostring(msg))
    promise:set("f1")
  end)

  local f2 = service:deferred(function (promise)
    local msg = zmq.message()
    promise:assert(service:zmq_msg_recv(msg, rep):get())
    print("f2-recv", tostring(msg))
    service:deferred(function () end):wait_for(0.5)
    local msg = zmq.message("bar")
    promise:assert(service:zmq_msg_send(msg, rep):get())
    print("f2-send", tostring(msg))
    promise:set("f2")
  end)

  service:when_all(f1, f2):get()

  assert(rep:close())
  assert(req:close())
  assert(ctx:term())

  service:stop()
end))
