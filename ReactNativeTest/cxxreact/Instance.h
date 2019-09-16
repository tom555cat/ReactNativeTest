//
//  Instance.hpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#pragma once

#include <memory>
#include <condition_variable>

#include "CxxNativeModule.h"

class JSExecutorFactory;
class MessageQueueThread;
class ModuleRegistry;

#warning struct与C++的关系
struct InstanceCallback {
    virtual ~InstanceCallback() {}
    virtual void onBatchComplete() {}
    virtual void incrementPendingJSCalls() {}
    virtual void decrementPendingJSCalls() {}
};

namespace facebook {
namespace react {

class RN_EXPORT Instance {
public:
    ~Instance();
    void initializeBridge(std::unique_ptr<InstanceCallback> callback,
                          std::shared_ptr<JSExecutorFactory> jsef,
                          std::shared_ptr<MessageQueueThread> jsQueue,
                          std::shared_ptr<ModuleRegistry> moduleRegistry);
private:
    // cxxBridge实现了回调方法
    std::shared_ptr<InstanceCallback> callback_;
    std::unique_ptr<NativeToJsBridge> nativeToJsBridge_;
    // module的registry
    std::shared_ptr<ModuleRegistry> moduleRegistry_;
};
    
}
}
