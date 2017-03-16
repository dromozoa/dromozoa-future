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

local uint32 = require "dromozoa.commons.uint32"
local unix = require "dromozoa.unix"
local curl = require "dromozoa.curl"
local create_thread = require "dromozoa.future.create_thread"
local futures = require "dromozoa.future.futures"
local io_handler = require "dromozoa.future.io_handler"
local io_service = require "dromozoa.future.io_service"
local resume_thread = require "dromozoa.future.resume_thread"
local timer_service = require "dromozoa.future.timer_service"

local super = futures
local class = {}

function class.new()
  local async_service = assert(unix.async_service())
  local curl_service = assert(curl.multi())

  local self = {
    timer_service = timer_service();
    io_service = io_service();
    async_service = async_service;
    async_threads = {};
    curl_service = curl_service;
    curl_threads = {};
  }

  assert(class.add_handler(self, io_handler(async_service:get(), "read", function ()
    while true do
      local result = async_service:read()
      if result > 0 then
        while true do
          local task = async_service:pop()
          if task then
            local thread = self.async_threads[task]
            self.async_threads[task] = nil
            if thread then
              resume_thread(thread, task)
            end
          else
            break
          end
        end
      end
      coroutine.yield()
    end
  end)))

  assert(curl_service:setopt(curl.CURLMOPT_SOCKETFUNCTION, function (_, fd, what)
    local read_handler, write_handler = self:get_handlers(fd)
    if what == curl.CURL_POLL_IN then
      if read_handler == nil then
        self:add_handler(io_handler(fd, "read", function ()
          while true do
            assert(curl_service:socket_action(fd, curl.CURL_POLL_IN))
            coroutine.yield()
          end
        end))
      end
      if write_handler ~= nil then
        self:remove_handler(write_handler)
      end
    elseif what == curl.CURL_POLL_OUT then
      if write_handler == nil then
        self:add_handler(io_handler(fd, "write", function ()
          while true do
            assert(curl_service:socket_action(fd, curl.CURL_POLL_OUT))
            coroutine.yield()
          end
        end))
      end
      if read_handler ~= nil then
        self:remove_handler(read_handler)
      end
    elseif what == curl.CURL_POLL_INOUT then
      if read_handler == nil then
        self:add_handler(io_handler(fd, "read", function ()
          while true do
            assert(curl_service:socket_action(fd, curl.CURL_POLL_IN))
            coroutine.yield()
          end
        end))
      end
      if write_handler == nil then
        self:add_handler(io_handler(fd, "write", function ()
          while true do
            assert(curl_service:socket_action(fd, curl.CURL_POLL_OUT))
            coroutine.yield()
          end
        end))
      end
    elseif what == curl.CURL_POLL_REMOVE then
      if read_handler ~= nil then
        self:remove_handler(read_handler)
      end
      if write_handler ~= nil then
        self:remove_handler(write_handler)
      end
    end
  end))

  assert(curl_service:setopt(curl.CURLMOPT_TIMERFUNCTION, function (_, timeout)
    if timeout == -1 then
      self:remove_timer(self.curl_timer)
      self.curl_timer = nil
    elseif timeout == 0 then
      assert(self.curl_service:socket_action(curl.CURL_SOCKET_TIMEOUT))
    else
      local b = timeout % 1000
      local a = (timeout - b) / 1000
      self.curl_timer = self:add_timer(self:get_current_time():add({ tv_sec = a, tv_nsec = b * 1000000 }), function (timer_handle)
        self:remove_timer(timer_handle)
        -- self.curl_timer = nil
        assert(self.curl_service:socket_action(curl.CURL_SOCKET_TIMEOUT))
      end)
    end
  end))

  return self
end

function class:get_current_time()
  return self.timer_service:get_current_time()
end

function class:add_timer(timeout, thread)
  return self.timer_service:add_timer(timeout, thread)
end

function class:remove_timer(handle)
  self.timer_service:remove_timer(handle)
  return self
end

function class:add_handler(handler)
  local result, message = self.io_service:add_handler(handler)
  if not result then
    return nil, message
  end
  return self
end

function class:remove_handler(handler)
  local result, message = self.io_service:remove_handler(handler)
  if not result then
    return nil, message
  end
  return self
end

function class:get_handlers(fd)
  return self.io_service:get_handlers(fd)
end

function class:add_task(task, thread)
  self.async_service:push(task)
  self.async_threads[task] = thread
  return self
end

function class:add_curl(easy, thread)
  local result, message = self.curl_service:add_handle(easy)
  if not result then
    return nil, message
  end
  self.curl_threads[easy:get_address()] = thread
  return self
end

function class:start()
  self.stopped = nil
  return self
end

function class:stop()
  self.stopped = true
  return self
end

function class:dispatch(thread)
  if thread ~= nil then
    resume_thread(create_thread(thread), self)
    if self.stopped then
      return self
    end
  end
  local timer_service = self.timer_service
  local io_service = self.io_service
  local curl_service = self.curl_service
  while true do
    timer_service:dispatch()
    if self.stopped then
      return self
    end
    io_service:dispatch()
    if self.stopped then
      return self
    end
    while true do
      local info, n = curl_service:info_read()
      if info == nil then
        break
      end
      if info.msg == curl.CURLMSG_DONE then
        local easy = info.easy_handle
        local address = easy:get_address()
        local thread = self.curl_threads[easy:get_address()]
        self.curl_service:remove_handle(easy)
        self.curl_threads[address] = nil
        if thread then
          resume_thread(thread, easy, info.result)
        end
      end
    end
    if self.stopped then
      return self
    end
  end
end

function class:set_current_state(current_state)
  self.current_state = current_state
end

function class:get_current_state()
  return self.current_state
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function ()
    return setmetatable(class.new(), class.metatable)
  end;
})
