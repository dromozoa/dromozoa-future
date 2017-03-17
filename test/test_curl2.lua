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

local sha256 = require "dromozoa.commons.sha256"
local unix = require "dromozoa.unix"
local curl = require "dromozoa.curl"
local future_service = require "dromozoa.future.future_service"
local reader_buffer = require "dromozoa.future.reader_buffer"

assert(future_service():dispatch(function (service)
  local easy = assert(curl.easy())
  assert(easy:setopt(curl.CURLOPT_URL, "http://dromozoa.s3.amazonaws.com/pub/dromozoa-autotoolize/1.2/lua-5.3.4.dromozoa-autotoolize-1.2.tar.gz"))
  local size = 0
  assert(easy:setopt(curl.CURLOPT_HEADERFUNCTION, function (data)
    local data = data:gsub("\r\n$", "")
    print(data)
  end))

  local ctx = sha256()

  local thread = coroutine.create(function (buffer)
    while true do
      local result = buffer:read(256)
      if result == nil then
        buffer = coroutine.yield()
      elseif result == "" then
        break
      else
        ctx:update(result)
      end
    end
  end)

  local buffer = reader_buffer()
  assert(easy:setopt(curl.CURLOPT_WRITEFUNCTION, function (data)
    size = size + #data
    buffer:write(data)
    coroutine.resume(thread, buffer)
  end))
  local f = service:curl_perform(easy)
  print("fetching")
  assert(f:get())
  print("fetched")
  assert(size == 648960)
  buffer:close()
  coroutine.resume(thread, buffer)

  assert(ctx:finalize("hex") == "9f6ca3818625f90f06f28cd9fc758017b8a09ead724b223fda2f3120810ff68c")

  easy:cleanup()
  service:stop()
end))
