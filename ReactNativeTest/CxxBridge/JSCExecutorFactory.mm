//
//  JSCExecutorFactory.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "JSCExecutorFactory.h"

namespace facebook {
namespace react {
    
std::unique_ptr<JSExecutor> JSCExecutorFactory::createJSExecutor(
  std::shared_ptr<ExecutorDelegate> delegate,
  std::shared_ptr<MessageQueueThread> jsQueue) {
  return folly::make_unique<JSIExecutor>(
       facebook::jsc::makeJSCRuntime(),
       delegate,
       [](const std::string &message, unsigned int logLevel) {
           _RCTLogJavaScriptInternal(
                                     static_cast<RCTLogLevel>(logLevel),
                                     [NSString stringWithUTF8String:message.c_str()]);
       },
       JSIExecutor::defaultTimeoutInvoker,
       std::move(runtimeInstaller_));
}
    
}
}
