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
local create_thread = require "dromozoa.future.create_thread"
local resume_thread = require "dromozoa.future.resume_thread"

local class = {}

function class.new(easy, thread)
  local self = {
    easy = easy;
    thread = create_thread(thread);
  }
  local result, message = easy:setopt(curl.CURLOPT_HEADERFUNCTION, function (data)
    self:dispatch("header", data)
  end)
  if not result then
    return nil, message
  end
  local result, message = easy:setopt(curl.CURLOPT_WRITEFUNCTION, function (data)
    self:dispatch("write", data)
  end)
  if not result then
    return nil, message
  end
  return self
end

function class:dispatch(event, data)
  resume_thread(self.thread, self, event, data)
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __call = function (_, easy, thread)
    local self, message = class.new(easy, thread)
    if self == nil then
      return nil, message
    end
    return setmetatable(self, class.metatable)
  end;
})
