//
//  Instance.cpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#include "Instance.h"

#include "MessageQueueThread.h"
#include "JSExecutorFactory.h"

// * jsQueue
// 该方法在RCTCxxBridge中被调用，传递的jsQueue是RCTCxxBridge的"std::shared_ptr<RCTMessageThread> _jsMessageThread;"
// jsQueue参数传递的是一个"std::shared_ptr<RCTMessageThread> _jsMessageThread;"，
// 是如何与"std::shared_ptr<MessageQueueThread>"类型勾搭起来的？
// class RCTMessageThread : public MessageQueueThread
// RCTMessageThread是继承自MessageQueueThread

// * jsef参数是在cxxBridge中用空参数创建的一个"std::make_shared<JSCExecutorFactory>(nullptr)"


void Instance::initializeBridge(
                                std::unique_ptr<InstanceCallback> callback,
                                std::shared_ptr<JSExecutorFactory> jsef,
                                std::shared_ptr<MessageQueueThread> jsQueue,
                                std::shared_ptr<ModuleRegistry> moduleRegistry) {
    callback_ = std::move(callback);
    moduleRegistry_ = std::move(moduleRegistry);
    // 在cxx的jsThread的runLoop上同步地执行任务
    jsQueue->runOnQueueSync([this, &jsef, jsQueue]() mutable {
        nativeToJsBridge_ = folly::make_unique<NativeToJsBridge>(
            jsef.get(), moduleRegistry_, jsQueue, callback_);
        
        std::lock_guard<std::mutex> lock(m_syncMutex);
        m_syncReady = true;
        m_syncCV.notify_all();
    });
    
    CHECK(nativeToJsBridge_);
}

void Instance::callJSFunction(std::string &&module, std::string &&method,
                              folly::dynamic &&params) {
    // cxxBridge实现了回调方法"callback"执行了一些方法
    callback_->incrementPendingJSCalls();
    // 关键是
    nativeToJsBridge_->callFunction(std::move(module), std::move(method),
                                    std::move(params));
}
