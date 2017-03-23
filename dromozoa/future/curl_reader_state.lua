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
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, reader)
  local self = super.new(service)
  self.reader = reader
  self.thread = coroutine.create(function ()
    if self:is_running() then
      self:set(true)
    else
      self.result = pack(true)
    end
  end)
  return self
end

function class:launch()
  super.launch(self)
  local thread = self.thread
  self.thread = nil
  self.reader.thread = thread
end

function class:resume()
  super.resume(self)
  local result = self.result
  self.result = nil
  if result then
    -- assert(self.caller == nil)
    self:set(true)
  end
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, reader)
    return setmetatable(class.new(service, reader), class.metatable)
  end;
})
