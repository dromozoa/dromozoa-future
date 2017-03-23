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
local curl = require "dromozoa.curl"
local future_service = require "dromozoa.future.future_service"

assert(future_service():dispatch(function (service)
  local easy1 = assert(curl.easy())
  assert(easy1:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local easy2 = assert(curl.easy())
  assert(easy2:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local easy3 = assert(curl.easy())
  assert(easy3:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local easy4 = assert(curl.easy())
  assert(easy4:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local f1, reader1, header1 = service:curl_perform(easy1)
  local f2, reader2, header2 = service:curl_perform(easy2)
  local f3 = service:curl_perform(easy3)
  local f4 = service:curl_perform(easy4)

  local f5 = service:deferred(function (promise)
    while true do
      local data = header1:read(16):get()
      if data == "" then
        break
      end
      print(("%q"):format(data))
    end
    promise:set(true)
  end)

  local f6 = service:deferred(function (promise)
    while true do
      local data = reader2:read(16):get()
      if data == "" then
        break
      end
      print(("%q"):format(data))
    end
    promise:set(true)
  end)

  local t1 = unix.clock_gettime(unix.CLOCK_MONOTONIC_RAW)
  service:when_all(f1, f2, f3, f4, f5, f6):wait_for(0.5)
  local t2 = unix.clock_gettime(unix.CLOCK_MONOTONIC_RAW)
  local t = t2 - t1
  print("!!! 1", tostring(t2 - t1))
  local a, b = service:when_all(f1, f2):get()
  local t3 = unix.clock_gettime(unix.CLOCK_MONOTONIC_RAW)
  local t = t3 - t1
  print("!!! 2", t:tostring())
  assert(t < 2.5)
  local c, d = service:when_all(f3, f4):get()
  print(a:get(), b:get(), c:get(), d:get())
  f5:get()
  f6:get()
  easy1:cleanup()
  easy2:cleanup()
  easy3:cleanup()
  easy4:cleanup()
  service:stop()
end))
