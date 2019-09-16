//
//  JSExecutorFactory.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include <memory>

#include "CxxNativeModule.h"
#include "MessageQueueThread.h"

namespace facebook {
namespace react {

class JSExecutor;

class ExecutorDelegate {
public:
    virtual ~ExecutorDelegate() {}
    
    virtual std::shared_ptr<ModuleRegistry> getModuleRegistry() = 0;
    
    virtual void callNativeModules(
                                   JSExecutor& executor, folly::dynamic&& calls, bool isEndOfBatch) = 0;
    virtual MethodCallResult callSerializableNativeHook(
                                                        JSExecutor& executor, unsigned int moduleId, unsigned int methodId, folly::dynamic&& args) = 0;
};
    
class JSExecutorFactory {
public:
    virtual std::unique_ptr<JSExecutor> createJSExecutor(
                                                         std::shared_ptr<ExecutorDelegate> delegate,
                                                         std::shared_ptr<MessageQueueThread> jsQueue) = 0;
    virtual ~JSExecutorFactory() {}
};

class RN_EXPORT JSExecutor {
    
};
    
}
}

