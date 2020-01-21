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
    
    // 执行JS代码进行了重写
    void evaluateJavaScript(
                            std::unique_ptr<const jsi::Buffer> buffer,
                            const std::string& sourceURL) override;
    // 返回一个全局对象进行了重写
    jsi::Object global() override;
    
protected:
    
    // 对JSObjectRef的封装，包含了JSObjectRef所在的ctx
    class JSCObjectValue final : public PointerValue {
        JSCObjectValue(
           JSGlobalContextRef ctx,
           const std::atomic<bool>& ctxInvalid,
           JSObjectRef obj
#ifndef NDEBUG
           ,
           std::atomic<intptr_t>& counter
#endif
        );
        
        void invalidate() override;
        
        JSGlobalContextRef ctx_;
        const std::atomic<bool>& ctxInvalid_;
        JSObjectRef obj_;
#ifndef NDEBUG
        std::atomic<intptr_t>& counter_;
#endif
    protected:
        friend class JSCRuntime;
    };
    
    
    jsi::Object createObject() override;
    jsi::Object createObject(std::shared_ptr<jsi::HostObject> ho) override;
    
private:
    jsi::Object createObject(JSObjectRef objectRef) const;
    
    jsi::Runtime::PointerValue* makeObjectValue(JSObjectRef obj) const;
    
    // A global JavaScript execution context
    JSGlobalContextRef ctx_;
};
    
// 创建的是一个和全局JS执行环境对象相关的一个Object
jsi::Object JSCRuntime::global() {
    // JSContextGetGlobalObject，返回JSObjectRef，获取JavaScript 执行context的全局对象。
    // JSObjectRef: A JavaScript object
    return createObject(JSContextGetGlobalObject(ctx_));
}
    
jsi::Object JSCRuntime::createObject() {
    return createObject(static_cast<JSObjectRef>(nullptr));
}
    
jsi::Object JSCRuntime::createObject(JSObjectRef obj) const {
    return make<jsi::Object>(makeObjectValue(obj));
}

jsi::Runtime::PointerValue* JSCRuntime::makeObjectValue(
      JSObjectRef objectRef) const {
    // 在通过global调用时，参数objectRef是不为空的，所以不用走这个if判断
    if (!objectRef) {
        // 创建一个JavaScript Object
        objectRef = JSObjectMake(ctx_, nullptr, nullptr);
    }
#ifndef NDEBUG
    return new JSCObjectValue(ctx_, ctxInvalid_, objectRef, objectCounter_);
#else
    // JSCObjectValue创建一个
    return new JSCObjectValue(ctx_, ctxInvalid_, objectRef);
#endif
}
    
jsi::Value JSCRuntime::getProperty(
                                   const jsi::Object& obj,
                                   const jsi::String& name) {
    JSObjectRef objRef = objectRef(obj);
    JSValueRef exc = nullptr;
    JSValueRef res = JSObjectGetProperty(ctx_, objRef, stringRef(name), &exc);
    checkException(exc);
    return createValue(res);
}

jsi::Value JSCRuntime::getProperty(
                                   const jsi::Object& obj,
                                   const jsi::PropNameID& name) {
    JSObjectRef objRef = objectRef(obj);
    JSValueRef exc = nullptr;
    JSValueRef res = JSObjectGetProperty(ctx_, objRef, stringRef(name), &exc);
    checkException(exc);
    return createValue(res);
}

jsi::Value JSCRuntime::call(
                            const jsi::Function& f,
                            const jsi::Value& jsThis,
                            const jsi::Value* args,
                            size_t count) {
    JSValueRef exc = nullptr;
    // 这个是通过系统函数来实现调用JS函数
    auto res = JSObjectCallAsFunction(
                                      ctx_,
                                      objectRef(f),
                                      jsThis.isUndefined() ? nullptr : objectRef(jsThis.getObject(*this)),
                                      count,
                                      detail::ArgsConverter(*this, args, count),
                                      &exc);
    checkException(exc);
    return createValue(res);
}
    
#warning 执行JS代码需要一个JSContext
// 通过"JSGlobalContextCreateInGroup"创建一个global context
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
