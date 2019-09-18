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
    JsToNativeBridge(std::shared_ptr<ModuleRegistry> registry,
                     std::shared_ptr<InstanceCallback> callback)
    : m_registry(registry)
    , m_callback(callback) {}
    
private:
    std::shared_ptr<ModuleRegistry> m_registry;
    std::shared_ptr<InstanceCallback> m_callback;
};
    
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
    
}
}
