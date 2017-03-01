package = "dromozoa-future"
version = "1.0-1"
source = {
  url = "https://github.com/dromozoa/dromozoa-future/archive/v1.0.tar.gz";
  file = "dromozoa-future-1.0.tar.gz";
}
description = {
  summary = "Toolkit for network and I/O programming";
  license = "GPL-3";
  homepage = "https://github.com/dromozoa/dromozoa-future/";
  maintainer = "Tomoyuki Fujimori <moyu@dromozoa.com>";
}
dependencies = {
  "dromozoa-commons";
  "dromozoa-dyld";
  "dromozoa-curl";
  "dromozoa-unix";
  "dromozoa-zmq";
}
build = {
  type = "builtin";
  modules = {
    ["dromozoa.future.async_state"] = "dromozoa/future/async_state.lua";
    ["dromozoa.future.create_thread"] = "dromozoa/future/create_thread.lua";
    ["dromozoa.future.deferred_state"] = "dromozoa/future/deferred_state.lua";
    ["dromozoa.future.future"] = "dromozoa/future/future.lua";
    ["dromozoa.future.future_service"] = "dromozoa/future/future_service.lua";
    ["dromozoa.future.futures"] = "dromozoa/future/futures.lua";
    ["dromozoa.future.io_handler"] = "dromozoa/future/io_handler.lua";
    ["dromozoa.future.io_handler_state"] = "dromozoa/future/io_handler_state.lua";
    ["dromozoa.future.io_service"] = "dromozoa/future/io_service.lua";
    ["dromozoa.future.latch_state"] = "dromozoa/future/latch_state.lua";
    ["dromozoa.future.make_ready_future"] = "dromozoa/future/make_ready_future.lua";
    ["dromozoa.future.never_return"] = "dromozoa/future/never_return.lua";
    ["dromozoa.future.promise"] = "dromozoa/future/promise.lua";
    ["dromozoa.future.reader"] = "dromozoa/future/reader.lua";
    ["dromozoa.future.reader_buffer"] = "dromozoa/future/reader_buffer.lua";
    ["dromozoa.future.reader_source"] = "dromozoa/future/reader_source.lua";
    ["dromozoa.future.ready_state"] = "dromozoa/future/ready_state.lua";
    ["dromozoa.future.resume_thread"] = "dromozoa/future/resume_thread.lua";
    ["dromozoa.future.shared_future"] = "dromozoa/future/shared_future.lua";
    ["dromozoa.future.shared_reader"] = "dromozoa/future/shared_reader.lua";
    ["dromozoa.future.shared_state"] = "dromozoa/future/shared_state.lua";
    ["dromozoa.future.sharer_state"] = "dromozoa/future/sharer_state.lua";
    ["dromozoa.future.state"] = "dromozoa/future/state.lua";
    ["dromozoa.future.timer_service"] = "dromozoa/future/timer_service.lua";
    ["dromozoa.future.when_any_table_state"] = "dromozoa/future/when_any_table_state.lua";
    ["dromozoa.future.writer"] = "dromozoa/future/writer.lua";
  };
}