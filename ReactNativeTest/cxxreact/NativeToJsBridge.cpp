//
//  NativeToJsBridge.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "NativeToJsBridge.h"

#include "JSExecutorFactory.h"
#include "ModuleRegistry.h"
#include "MessageQueueThread.h"
#include "JSExecutor.h"

namespace facebook {
namespace react {
    
// ExecutorDelegate就是提供JS调用原生方法的接口，所以
// JsToNativeBridge的名字也很合理
class JsToNativeBridge : public react::ExecutorDelegate {
public:
    // * registry是在cxxBridge中创建的ModuleRegistry
    // * callback是cxxBridge实例
    JsToNativeBridge(std::shared_ptr<ModuleRegistry> registry,
                     std::shared_ptr<InstanceCallback> callback)
    : m_registry(registry)
    , m_callback(callback) {}
    
private:
    std::shared_ptr<ModuleRegistry> m_registry;
    std::shared_ptr<InstanceCallback> m_callback;
};
    
// * jsQueue是CxxBridge的"std::shared_ptr<RCTMessageThread> _jsMessageThread;"，
// RCTMessageThread继承自MessageQueueThread,
// 所以m_executorMessageQueueThread是用CxxBridge的_jsMessageThread来初始化的
    
// * 第一个参数jsExecutorFactory是在cxxBridge中用空参数创建的一个"std::make_shared<JSCExecutorFactory>(nullptr)，
// 然后通过instance调用NativeToJsBridge的构造函数时传递进来的。
// 然后利用这个jsExecutorFactory创建了JSIExecutor赋值给了m_executor
    
// * callback是cxxBridge实例，
    
// * registry是cxxBridge中创建的ModuleRegistry，通过instance的方法来传递过来的。
    
NativeToJsBridge::NativeToJsBridge(
                                   JSExecutorFactory* jsExecutorFactory,
                                   std::shared_ptr<ModuleRegistry> registry,
                                   std::shared_ptr<MessageQueueThread> jsQueue,
                                   std::shared_ptr<InstanceCallback> callback)
    : m_destroyed(std::make_shared<bool>(false))
    , m_delegate(std::make_shared<JsToNativeBridge>(registry, callback))
    , m_executor(jsExecutorFactory->createJSExecutor(m_delegate, jsQueue))
    , m_executorMessageQueueThread(std::move(jsQueue)) {}


NativeToJsBridge::~NativeToJsBridge() {
    CHECK(*m_destroyed) <<
    "NativeToJsBridge::destroy() must be called before deallocating the NativeToJsBridge!";
}

void NativeToJsBridge::callFunction(
    std::string &&module,
    std::string &&method,
    folly::dynamic&& arguments) {
    
    int systraceCookie = -1;
    #ifdef WITH_FBSYSTRACE
    systraceCookie = m_systraceCookie++;
    FbSystraceAsyncFlow::begin(
                               TRACE_TAG_REACT_CXX_BRIDGE,
                               "JSCall",
                               systraceCookie);
    #endif
    
    // 执行这个lambda，需要一个参数executor，根据下面runOnExecutorQueue函数来看，这个executor
    // 是m_executor.get()，是一个JSIExecutor;
    // 核心部分就是"executor->callFunction(module, method, arguments);"***
    // "executor->callFunction(module, method, arguments);"是在cxxBridge的"_jsMessageThread"上
    // 异步地执行
    runOnExecutorQueue([this, module = std::move(module), method = std::move(method), arguments = std::move(arguments), systraceCookie]
   (JSExecutor* executor) {
       if (m_applicationScriptHasFailure) {
           LOG(ERROR) << "Attempting to call JS function on a bad application bundle: " << module.c_str() << "." << method.c_str() << "()";
           throw std::runtime_error("Attempting to call JS function on a bad application bundle: " + module + "." + method + "()");
       }
       
#ifdef WITH_FBSYSTRACE
       FbSystraceAsyncFlow::end(
                                TRACE_TAG_REACT_CXX_BRIDGE,
                                "JSCall",
                                systraceCookie);
       SystraceSection s("NativeToJsBridge::callFunction", "module", module, "method", method);
#else
       (void)(systraceCookie);
#endif
       // This is safe because we are running on the executor's thread: it won't
       // destruct until after it's been unregistered (which we check above) and
       // that will happen on this thread
       executor->callFunction(module, method, arguments);
   });
    
    
}

void NativeToJsBridge::runOnExecutorQueue(std::function<void(JSExecutor*)> task) {
    if (*m_destroyed) {
        return;
    }
    
    std::shared_ptr<bool> isDestroyed = m_destroyed;
    // 在cxxBridge的"_jsMessageThread"上异步地执行任务。
    m_executorMessageQueueThread->runOnQueue([this, isDestroyed, task=std::move(task)] {
        if (*isDestroyed) {
            return;
        }
        
        // The executor is guaranteed to be valid for the duration of the task because:
        // 1. the executor is only destroyed after it is unregistered
        // 2. the executor is unregistered on this queue
        // 3. we just confirmed that the executor hasn't been unregistered above
        task(m_executor.get());
    });
}
    
} }
