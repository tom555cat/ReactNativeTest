//
//  JSCExecutorFactory.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "JSExecutorFactory.h"
#include "JSIExecutor.h"

namespace facebook {
namespace react {

// 继承了一个工厂模式的虚基类JSExecutorFactory，自己内部实现了工厂方法createJSExecutor
class JSCExecutorFactory : public JSExecutorFactory {
public:
    explicit JSCExecutorFactory(
        JSIExecutor::RuntimeInstaller runtimeInstaller)
        : runtimeInstaller_(std::move(runtimeInstaller)) {}
    
    std::unique_ptr<JSExecutor> createJSExecutor(
                                                 std::shared_ptr<ExecutorDelegate> delegate,
                                                 std::shared_ptr<MessageQueueThread> jsQueue) override;
    
private:
    JSIExecutor::RuntimeInstaller runtimeInstaller_;
};
    
} // namespace react
} // namespace facebook
