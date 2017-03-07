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

local pack = require "dromozoa.commons.pack"
local unpack = require "dromozoa.commons.unpack"
local io_handler = require "dromozoa.future.io_handler"
local io_poller_service = require "dromozoa.future.io_poller_service"
local io_selector_service = require "dromozoa.future.io_selector_service"

local class = {}

function class.new()
  local poller_service = io_poller_service()
  local selector_service = io_selector_service()
  local self = {
    poller_service = poller_service;
    selector_service = selector_service;
  }
  poller_service:add_handler(io_handler(selector_service.selector:get(), "read", function ()
    while true do
      self.selector_result = pack(selector_service:dispatch())
      coroutine.yield()
    end
  end))
  return self
end

function class:add_handler(handler)
  local service
  if handler.socket == nil then
    service = self.selector_service
  else
    service = self.poller_service
  end
  local result, message, code = service:add_handler(handler)
  if not result then
    return nil, message, code
  end
  return self
end

function class:remove_handler(handler)
  local service
  if handler.socket == nil then
    service = self.selector_service
  else
    service = self.poller_service
  end
  local result, message, code = service:remove_handler(handler)
  if not result then
    return nil, message, code
  end
  return self
end

function class:dispatch()
  self.selector_result = nil
  local result, message, code = self.poller_service:dispatch()
  if not result then
    return nil, message, code
  end
  local selector_result = self.selector_result
  if selector_result ~= nil then
    self.selector_result = nil
    result, message, code = unpack(selector_result, 1, selector_result.n)
    if not result then
      return nil, message, code
    end
  end
  return self
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function ()
    return setmetatable(class.new(), class.metatable)
  end;
})
