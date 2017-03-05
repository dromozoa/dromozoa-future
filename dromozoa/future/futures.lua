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

local deferred_state = require "dromozoa.future.deferred_state"
local future = require "dromozoa.future.future"
local io_futures = require "dromozoa.future.io_futures"
local latch_state = require "dromozoa.future.latch_state"
local make_ready_future = require "dromozoa.future.make_ready_future"
local shared_future = require "dromozoa.future.shared_future"
local shared_state = require "dromozoa.future.shared_state"
local when_any_table_state = require "dromozoa.future.when_any_table_state"

local super = io_futures
local class = {}

function class.deferred(service, thread)
  return future(deferred_state(service, thread))
end

function class.when_all(service, ...)
  return future(latch_state(service, "n", ...))
end

function class.when_any(service, ...)
  return future(latch_state(service, 1, ...))
end

function class.when_any_table(service, futures)
  return future(when_any_table_state(service, futures))
end

function class.make_ready_future(_, ...)
  return make_ready_future(...)
end

function class.make_shared_future(service, future)
  local state = future.state
  future.state = nil
  return shared_future(service, shared_state(service, state))
end

return setmetatable(class, {
  __index = super;
})
