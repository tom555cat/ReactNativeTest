//
//  JSCRuntime.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "JSCRuntime.h"

#include <JavaScriptCore/JavaScript.h>



namespace facebook {
namespace jsc {
    
class JSCRuntime : public jsi::Runtime {
public:
    JSCRuntime();
    JSCRuntime(JSGlobalContextRef ctx);
    ~JSCRuntime();
};
    
    
#warning 执行JS代码需要一个JSContext
JSCRuntime::JSCRuntime()
    : JSCRuntime(JSGlobalContextCreateInGroup(nullptr, nullptr)) {
        JSGlobalContextRelease(ctx_);
}
    
JSCRuntime::JSCRuntime(JSGlobalContextRef ctx)
    : ctx_(JSGlobalContextRetain(ctx)),
    ctxInvalid_(false)
#ifndef NDEBUG
    ,
    objectCounter_(0),
    stringCounter_(0)
#endif
{
}
    
std::unique_ptr<jsi::Runtime> makeJSCRuntime() {
    return std::make_unique<JSCRuntime>();
}
    
}
}
