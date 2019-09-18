//
//  JSIExecutor.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "JSIExecutor.h"

using namespace facebook::jsi;

namespace facebook {
namespace react {
    
JSIExecutor::JSIExecutor(
                         std::shared_ptr<jsi::Runtime> runtime,
                         std::shared_ptr<ExecutorDelegate> delegate,
                         Logger logger,
                         const JSIScopedTimeoutInvoker& scopedTimeoutInvoker,
                         RuntimeInstaller runtimeInstaller)
    : runtime_(runtime),
    delegate_(delegate),
    nativeModules_(delegate ? delegate->getModuleRegistry() : nullptr),
    logger_(logger),
    scopedTimeoutInvoker_(scopedTimeoutInvoker),
    runtimeInstaller_(runtimeInstaller) {
        runtime_->global().setProperty(
                                       *runtime, "__jsiExecutorDescription", runtime->description());
    }
    
}
}
