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
local curl_handler = require "dromozoa.future.curl_handler"
local curl_reader = require "dromozoa.future.curl_reader"
local reader_buffer = require "dromozoa.future.reader_buffer"
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, easy)
  local self = super.new(service)
  local header = curl_reader(service, self)
  local reader = curl_reader(service, self)
  local handler, message = curl_handler(easy, coroutine.create(function (_, event, data)
    while true do
      if event == "header" then
        header:write(data)
        if data == "\r\n" then
          header:close()
        end
      elseif event == "write" then
        reader:write(data)
      elseif event == "done" then
        reader:close()
        if self:is_running() then
          self:set(data)
        else
          self.result = pack(data)
        end
        return
      end
      _, event, data = coroutine.yield()
    end
  end))
  if handler == nil then
    return nil, message
  end
  self.handler = handler
  return self, reader, header
end

function class:launch()
  super.launch(self)
  assert(self.service:add_curl_handler(self.handler))
end

function class:resume()
  super.resume(self)
  local result = self.result
  self.result = nil
  if result then
    self:set(unpack(result, 1, result.n))
  end
end

function class:finish()
  super.finish(self)
  local handler = self.handler
  self.handler = nil
  assert(self.service:remove_curl_handler(handler))
end

class.metatable = {
  __index = class;
}

return setmetatable(class, {
  __index = super;
  __call = function (_, service, easy)
    local self, reader, header = class.new(service, easy)
    return setmetatable(self, class.metatable), reader, header
  end;
})
