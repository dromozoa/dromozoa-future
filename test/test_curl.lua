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

local curl = require "dromozoa.curl"
local future_service = require "dromozoa.future.future_service"

assert(future_service():dispatch(function (service)
  local easy1 = assert(curl.easy())
  assert(easy1:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local easy2 = assert(curl.easy())
  assert(easy2:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.1&sleep_count=10"))
  local f1 = service:curl_perform(easy1)
  local f2 = service:curl_perform(easy2)
  service:when_all(f1, f2):get()
  service:stop()
end))
