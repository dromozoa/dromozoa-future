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
  local f1 = service:curl_perform(easy1)
  local f2 = service:curl_perform(easy2)
  local f3 = service:curl_perform(easy3)
  local f4 = service:curl_perform(easy4)
  local t1 = unix.clock_gettime(unix.CLOCK_MONOTONIC_RAW)
  service:when_all(f1, f2, f3, f4):get()
  -- assert(f1:get())
  local t2 = unix.clock_gettime(unix.CLOCK_MONOTONIC_RAW)
  local t = t2 - t1
  print(t:tostring())
  assert(t < 2.5)
  easy1:cleanup()
  easy2:cleanup()
  easy3:cleanup()
  easy4:cleanup()
  service:stop()
end))
