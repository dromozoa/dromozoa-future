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
local create_thread = require "dromozoa.future.create_thread"
local curl_service = require "dromozoa.future.curl_service"
local futures = require "dromozoa.future.futures"
local io_handler = require "dromozoa.future.io_handler"
local io_service = require "dromozoa.future.io_service"
local resume_thread = require "dromozoa.future.resume_thread"
local timer_service = require "dromozoa.future.timer_service"

local function make_async_io_handler(self, async_service)
  return io_handler(async_service:get(), "read", function ()
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
  end)
end

local function prepare_async_service(self)
  if self.async_service == nil then
    local async_service, message = unix.async_service()
    if async_service == nil then
      return nil, message
    end
    local result, message = self:add_handler(make_async_io_handler(self, async_service))
    if not result then
      return nil, message
    end
    self.async_service = async_service
    self.async_threads = {}
  end
  return self
end

local function prepare_curl_service(self)
  if self.curl_service == nil then
    local curl_service, message = curl_service(self)
    if curl_service == nil then
      return nil, message
    end
    self.curl_service = curl_service
  end
  return self
end

local super = futures
local class = {}

function class.new()
  local self = {
    timer_service = timer_service();
    io_service = io_service();
  }
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
  local result, message = prepare_async_service(self)
  if not result then
    return nil, message
  end
  self.async_service:push(task)
  self.async_threads[task] = thread
  return self
end

function class:add_curl_handler(handler)
  local result, message = prepare_curl_service(self)
  if not result then
    return nil, message
  end
  local result, message = self.curl_service:add_handler(handler)
  if not result then
    return nil, message
  end
  return self
end

function class:remove_curl_handler(handler)
  local result, message = self.curl_service:remove_handler(handler)
  if not result then
    return nil, message
  end
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
  while true do
    timer_service:dispatch()
    if self.stopped then
      return self
    end
    local result, message = io_service:dispatch()
    if not result then
      return nil, message
    end
    if self.stopped then
      return self
    end
    local curl_service = self.curl_service
    if curl_service ~= nil then
      curl_service:dispatch()
      if self.stopped then
        return self
      end
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
