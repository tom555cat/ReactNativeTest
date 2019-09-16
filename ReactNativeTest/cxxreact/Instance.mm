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

void Instance::initializeBridge(
                                std::unique_ptr<InstanceCallback> callback,
                                std::shared_ptr<JSExecutorFactory> jsef,
                                std::shared_ptr<MessageQueueThread> jsQueue,
                                std::shared_ptr<ModuleRegistry> moduleRegistry) {
    callback_ = std::move(callback);
    moduleRegistry_ = std::move(moduleRegistry);
    jsQueue->runOnQueueSync([this, &jsef, jsQueue]() mutable {
        nativeToJsBridge_ = folly::make_unique<NativeToJsBridge>(
                                                                 jsef.get(), moduleRegistry_, jsQueue, callback_);
        
        std::lock_guard<std::mutex> lock(m_syncMutex);
        m_syncReady = true;
        m_syncCV.notify_all();
    });
    
    CHECK(nativeToJsBridge_);
}
