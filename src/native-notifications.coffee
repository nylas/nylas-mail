
###
Mac OS X native notification integration is currently disabled because it causes
the app to segfault eventually with this exception trace:

It seems this issue is fixed in Node 4.1. Revisit after moving to Electron v0.33.2
https://github.com/node-ffi/node-ffi/issues/239

Exception Type:        EXC_BAD_ACCESS (SIGSEGV)
Exception Codes:       EXC_I386_GPFLT
​
0   binding.node                  	0x0000000123580d61 (anonymous namespace)::ReadObject(Nan::FunctionCallbackInfo<v8::Value> const&) + 225
1   binding.node                  	0x000000012358213a Nan::imp::FunctionCallbackWrapper(v8::FunctionCallbackInfo<v8::Value> const&) + 131
2   libv8.dylib                   	0x000000010e3a3a1f v8::internal::FunctionCallbackArguments::Call(void (*)(v8::FunctionCallbackInfo<v8::Value> const&)) + 159
...
16  libv8.dylib                   	0x000000010e4cb2ee 0x10e370000 + 1422062
17  libv8.dylib                   	0x000000010e38f434 v8::Function::Call(v8::Local<v8::Context>, v8::Handle<v8::Value>, int, v8::Handle<v8::Value>*) + 276
18  libnode.dylib                 	0x000000010d9b64a8 node::MakeCallback(node::Environment*, v8::Handle<v8::Value>, v8::Handle<v8::Function>, int, v8::Handle<v8::Value>*) + 1352
19  libnode.dylib                 	0x000000010d9b6edf node::MakeCallback(v8::Isolate*, v8::Handle<v8::Object>, v8::Handle<v8::Function>, int, v8::Handle<v8::Value>*) + 191
20  ffi_bindings.node             	0x000000012358a037 Nan::Callback::Call_(v8::Isolate*, v8::Local<v8::Object>, int, v8::Local<v8::Value>*) const + 105
21  ffi_bindings.node             	0x000000012358a35e CallbackInfo::DispatchToV8(_callback_info*, void*, void**, bool) + 334
22  ffi_bindings.node             	0x000000012358a95f CallbackInfo::Invoke(ffi_cif*, void*, void**, void*) + 69
23  ffi_bindings.node             	0x000000012358e526 ffi_closure_unix64_inner + 667
24  ffi_bindings.node             	0x000000012358ea7e ffi_closure_unix64 + 70
25  com.apple.Foundation          	0x00007fff8af5ca88 -[_NSConcreteUserNotificationCenter _shouldPresentNotification:] + 236
26  com.apple.Foundation          	0x00007fff8af5af13 __54-[_NSConcreteUserNotificationCenter _serverConnection]_block_invoke_2 + 292
27  libdispatch.dylib             	0x00007fff8f584700 _dispatch_call_block_and_release + 12
28  libdispatch.dylib             	0x00007fff8f580e73 _dispatch_client_callout + 8

---

ipc = require 'ipc'

class NativeNotifications
  constructor: ->
    @_handlers = {}
    ipc.on 'activate-native-notification', ({tag, activationType, response}) =>
      @_handlers[tag]?({tag, activationType, response})

  displayNotification: ({title, subtitle, body, tag, canReply, onActivate} = {}) =>
    if not tag
      throw new Error("NativeNotifications:displayNotification: A tag is required.")

    if process.platform in ['darwin', 'win32']
      ipc.send('fire-native-notification', {title, subtitle, body, tag, canReply})
      @_handlers[tag] = onActivate
    else
      notif = new Notification(title, {
        tag: tag
        body: subtitle
      })
      notif.onclick = => onActivate({tag, activationType: 'contents-clicked'})
###

class NativeNotifications
  constructor: ->

  displayNotification: ({title, subtitle, body, tag, canReply, onActivate} = {}) =>
    n = new Notification(title, {
      body: subtitle
      tag: tag
    })
    n.onclick = onActivate

module.exports = new NativeNotifications
