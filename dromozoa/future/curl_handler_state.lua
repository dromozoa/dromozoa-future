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
local promise = require "dromozoa.future.promise"
local reader_buffer = require "dromozoa.future.reader_buffer"
local state = require "dromozoa.future.state"

local super = state
local class = {}

function class.new(service, easy)
  local self = super.new(service)

  local header = curl_reader(service, self)
  local reader = curl_reader(service, self)

  local handler, message = curl_handler(easy, coroutine.create(function (event, data)
    local promise = promise(self)
    while true do
      if event == "header" then
        header:write(data)
        if data == "\r\n" then
          header:close()
        end
      elseif event == "write" then
        reader:write(data)
      elseif event == "done" then
        print("done")
        reader:close()
        if self:is_running() then
          self:set(data)
        else
          self.curl_result = pack(data)
        end
        -- return
      end
      event, data = coroutine.yield()
    end
  end))
  if handler == nil then
    return handler, message
  end

  self.easy = easy
  self.header = header
  self.reader = reader
  self.handler = handler
  return self
end

function class:launch()
  super.launch(self)
  assert(self.service:add_curl_handler(self.handler))
end

function class:resume()
  super.resume(self)
  local curl_result = self.curl_result
  self.curl_result = nil
  if curl_result then
    assert(self.caller == nil)
    self:set(unpack(curl_result, 1, curl_result.n))
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
    return setmetatable(class.new(service, easy), class.metatable)
  end;
})
