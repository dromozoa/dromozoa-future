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
    assert(service:zmq_send(req, 42):get())
    print("f1-send")
    local msg = promise:assert(service:zmq_recv(req):get())
    print("f1-recv")
    assert(tostring(msg) == "foobarbaz")
    promise:set("f1")
  end)

  local f2 = service:deferred(function (promise)
    local msg = promise:assert(service:zmq_recv(rep):get())
    print("f2-recv")
    assert(tostring(msg) == "42")
    service:deferred(function () end):wait_for(0.5)
    assert(service:zmq_send(rep, zmq.message("foobarbaz")):get())
    print("f2-send")
    promise:set("f2")
  end)

  service:when_all(f1, f2):get()

  assert(rep:close())
  assert(req:close())
  assert(ctx:term())

  service:stop()
end))
