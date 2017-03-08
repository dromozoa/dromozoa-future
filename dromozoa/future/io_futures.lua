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
local uint32 = require "dromozoa.commons.uint32"
local unix = require "dromozoa.unix"
local future = require "dromozoa.future.future"
local io_handler_state = require "dromozoa.future.io_handler_state"
local reader = require "dromozoa.future.reader"
local reader_source = require "dromozoa.future.reader_source"
local shared_reader = require "dromozoa.future.shared_reader"
local writer = require "dromozoa.future.writer"

local function is_resource_unavailable_try_again()
  local code = unix.get_last_errno()
  return code == unix.EAGAIN or code == unix.EWOULDBLOCK
end

local SOCK_COE_NDELAY_ON = uint32.bor(unix.SOCK_CLOEXEC, unix.SOCK_NONBLOCK)

local class = {}

function class.io_handler(service, fd, event, thread)
  return future(io_handler_state(service, fd, event, thread))
end

function class.accept(service, fd)
  return service:deferred(function (promise)
    assert(fd:is_ndelay_on())
    local result, address = fd:accept(SOCK_COE_NDELAY_ON)
    if result then
      return promise:set(result, address)
    elseif is_resource_unavailable_try_again() then
      local future = service:io_handler(fd, "read", function (promise)
        while true do
          assert(fd:is_ndelay_on())
          local result, address = fd:accept(SOCK_COE_NDELAY_ON)
          if result then
            return promise:set(result, address)
          elseif is_resource_unavailable_try_again() then
            promise = coroutine.yield()
          else
            return promise:set(unix.get_last_error())
          end
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(unix.get_last_error())
    end
  end)
end

function class.connect(service, fd, address)
  return service:deferred(function (promise)
    assert(fd:is_ndelay_on())
    local result = fd:connect(address)
    if result then
      return promise:set(result)
    elseif unix.get_last_errno() == unix.EINPROGRESS then
      local future = service:io_handler(fd, "write", function (promise)
        local code = fd:getsockopt(unix.SOL_SOCKET, unix.SO_ERROR)
        if code then
          if code == 0 then
            return promise:set(fd)
          else
            return promise:set(nil, unix.strerror(code), code)
          end
        else
          return promise:set(unix.get_last_error())
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(unix.get_last_error())
    end
  end)
end

function class.read(service, fd, size)
  return service:deferred(function (promise)
    assert(fd:is_ndelay_on())
    local result = fd:read(size)
    if result then
      return promise:set(result)
    elseif is_resource_unavailable_try_again() then
      local future = service:io_handler(fd, "read", function (promise)
        while true do
          assert(fd:is_ndelay_on())
          local result = fd:read(size)
          if result then
            return promise:set(result)
          elseif is_resource_unavailable_try_again() then
            promise = coroutine.yield()
          else
            return promise:set(unix.get_last_error())
          end
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(unix.get_last_error())
    end
  end)
end

function class.write(service, fd, buffer, i, j)
  return service:deferred(function (promise)
    assert(fd:is_ndelay_on())
    local result = fd:write(buffer, i, j)
    if result then
      return promise:set(result)
    elseif is_resource_unavailable_try_again() then
      local future = service:io_handler(fd, "write", function (promise)
        while true do
          assert(fd:is_ndelay_on())
          local result = fd:write(buffer, i, j)
          if result then
            return promise:set(result)
          elseif is_resource_unavailable_try_again() then
            promise = coroutine.yield()
          else
            return promise:set(unix.get_last_error())
          end
        end
      end)
      return promise:set(future:get())
    else
      return promise:set(unix.get_last_error())
    end
  end)
end

function class.make_reader(service, fd)
  return reader(service, reader_source(service, fd))
end

function class.make_shared_reader(service, fd)
  return shared_reader(service, fd)
end

function class.make_writer(service, fd)
  return writer(service, fd)
end

function class.bind_tcp(service, nodename, servname)
  return service:deferred(function (promise)
    local addrinfo, message, code = service:getaddrinfo(nodename, servname, { ai_socktype = unix.SOCK_STREAM, ai_flags = unix.AI_PASSIVE }):get()
    if addrinfo == nil then
      return promise:set(nil, message, code)
    end
    local result = sequence()
    for ai in sequence.each(addrinfo) do
      local fd = unix.socket(ai.ai_family, uint32.bor(ai.ai_socktype, SOCK_COE_NDELAY_ON), ai.ai_protocol)
      if fd == nil then
        return promise:set(unix.get_last_error())
      end
      if fd:setsockopt(unix.SOL_SOCKET, unix.SO_REUSEADDR, 1) and fd:bind(ai.ai_addr) and fd:listen() then
        result:push(fd)
      else
        code = unix.get_last_errno()
        message = unix.strerror(code)
        fd:close()
      end
    end
    if #result == 0 then
      return promise:set(nil, message, code)
    else
      return promise:set(result)
    end
  end)
end

function class.connect_tcp(service, nodename, servname)
  return service:deferred(function (promise)
    local addrinfo, message, code = service:getaddrinfo(nodename, servname, { ai_socktype = unix.SOCK_STREAM }):get()
    if addrinfo == nil then
      return promise:set(nil, message, code)
    end
    local future
    for ai in sequence.each(addrinfo) do
      local fd = unix.socket(ai.ai_family, uint32.bor(ai.ai_socktype, SOCK_COE_NDELAY_ON), ai.ai_protocol)
      if fd == nil then
        return promise:set(unix.get_last_error())
      end
      future = service:connect(fd, ai.ai_addr)
      if future:get() then
        return promise:set(fd)
      else
        fd:close()
      end
    end
    return promise:set(future:get())
  end)
end

return class
