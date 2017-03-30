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

local sequence = require "dromozoa.commons.sequence"
local unix = require "dromozoa.unix"
local curl = require "dromozoa.curl"
local future_service = require "dromozoa.future.future_service"

assert(future_service():dispatch(function (service)
  local easy = assert(curl.easy())
  assert(easy:setopt(curl.CURLOPT_URL, "http://localhost/cgi-bin/nph-dromozoa-curl-test.cgi?command=sleep&sleep_duration=0.5&sleep_count=10"))

  local f, reader, header = service:curl_perform(easy)

  local result, capture = assert(header:read_until("\r\n(X%-[^:]+):"):get())
  print(("[%q %q]"):format(result, capture))
  assert(capture == "X-LWS")

  while true do
    local result = assert(header:read_any(1024):get())
    if result == "" then
      break
    end
    print(("%q"):format(result))
  end

  local data = sequence()
  while true do
    local result = assert(reader:read_any(1024):get())
    if result == "" then
      break
    end
    print(("%q"):format(result))
    data:push(result)
  end

  assert(f:get() == 0)

  assert(#data == 10)

  easy:cleanup()
  service:stop()
end))
