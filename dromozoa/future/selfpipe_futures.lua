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

local class = {}

function class.selfpipe(service)
  return service:deferred(function (promise)
    local result = unix.selfpipe.read()
    if result > 0 then
      return promise:set(result)
    else
      local future = service:io_handler(unix.selfpipe.get(), "read", function (promise)
        while true do
          local result = unix.selfpipe.read()
          if result > 0 then
            return promise:set(result)
          else
            promise = coroutine.yield()
          end
        end
      end)
      return promise:set(future:get())
    end
  end)
end

function class.wait(service, pid)
  return service:deferred(function (promise)
    while true do
      local result, code, status = unix.wait(pid, unix.WNOHANG)
      if result then
        if result == 0 then
          if service.shared_selfpipe_future == nil or service.shared_selfpipe_future:is_ready() then
            service.shared_selfpipe_future = service:make_shared_future(service:selfpipe())
          end
          service.shared_selfpipe_future:share():get()
        else
          return promise:set(result, code, status)
        end
      else
        return promise:set(unix.get_last_error())
      end
    end
  end)
end

return class
