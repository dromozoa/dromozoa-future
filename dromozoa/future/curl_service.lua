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
local io_handler = require "dromozoa.future.io_handler"

local function make_curl_io_handler(multi, fd, event, what)
  return io_handler(fd, event, function ()
    while true do
      assert(multi:socket_action(fd, what))
      coroutine.yield()
    end
  end)
end

local function prepare_socket_function(_, multi, service)
  return multi:setopt(curl.CURLMOPT_SOCKETFUNCTION, function (_, fd, what)
    local read_handler, write_handler = service:get_handlers(fd)
    if what == curl.CURL_POLL_IN then
      if read_handler == nil then
        assert(service:add_handler(make_curl_io_handler(multi, fd, "read", curl.CURL_POLL_IN)))
      end
      if write_handler ~= nil then
        assert(service:remove_handler(write_handler))
      end
    elseif what == curl.CURL_POLL_OUT then
      if write_handler == nil then
        assert(service:add_handler(make_curl_io_handler(multi, fd, "write", curl.CURL_POLL_OUT)))
      end
      if read_handler ~= nil then
        assert(service:remove_handler(read_handler))
      end
    elseif what == curl.CURL_POLL_INOUT then
      if read_handler == nil then
        assert(service:add_handler(make_curl_io_handler(multi, fd, "read", curl.CURL_POLL_IN)))
      end
      if write_handler == nil then
        assert(service:add_handler(make_curl_io_handler(multi, fd, "write", curl.CURL_POLL_OUT)))
      end
    elseif what == curl.CURL_POLL_REMOVE then
      if read_handler ~= nil then
        assert(service:remove_handler(read_handler))
      end
      if write_handler ~= nil then
        assert(service:remove_handler(write_handler))
      end
    end
  end)
end

local function prepare_timer_function(self, multi, service)
  return multi:setopt(curl.CURLMOPT_TIMERFUNCTION, function (_, timeout_ms)
    if timeout_ms == -1 then
      local timer_handle = self.timer_handle
      self.timer_handle = nil
      if timer_handle ~= nil then
        service:remove_timer(timer_handle)
      end
    elseif timeout_ms == 0 then
      assert(multi:socket_action(curl.CURL_SOCKET_TIMEOUT))
    else
      local b = timeout_ms % 1000
      local a = (timeout_ms - b) / 1000
      local timeout = service:get_current_time():add({ tv_sec = a, tv_nsec = b * 1000000 })
      self.timer_handle = service:add_timer(timeout, function (timer_handle)
        service:remove_timer(timer_handle)
        if self.timer_handle == timer_handle then
          self.timer_handle = nil
        end
        assert(multi:socket_action(curl.CURL_SOCKET_TIMEOUT))
      end)
    end
  end)
end

local class = {}

function class.new(service)
  local multi = curl.multi()
  local self = {
    multi = multi;
    handlers = {};
  }
  local result, message = prepare_socket_function(self, multi, service)
  if not result then
    return nil, message
  end
  local result, message = prepare_timer_function(self, multi, service)
  if not result then
    return nil, message
  end
  return self
end

function class:add_handler(handler)
  local easy = handler.easy
  local result, message = self.multi:add_handle(easy)
  if not result then
    return nil, message
  end
  self.handlers[easy:get_address()] = handler
  return self
end

function class:remove_handler(handler)
  local easy = handler.easy
  local result, message = self.multi:remove_handle(easy)
  if not result then
    return nil, message
  end
  self.handlers[easy:get_address()] = nil
  return self
end

function class:dispatch()
  local multi = self.multi
  local handlers = self.handlers
  while true do
    local info = multi:info_read()
    if info == nil then
      return self
    end
    if info.msg == curl.CURLMSG_DONE then
      handlers[info.easy_handle:get_address()]:dispatch("done", info.result)
    end
  end
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, service)
    local self, message = class.new(service)
    if self == nil then
      return nil, message
    end
    return setmetatable(self, class.metatable)
  end;
})
