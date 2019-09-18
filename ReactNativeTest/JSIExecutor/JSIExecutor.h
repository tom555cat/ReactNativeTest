//
//  JSIExecutor.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#ifndef JSIExecutor_hpp
#define JSIExecutor_hpp

#include <stdio.h>
#include "JSExecutor.h"

namespace facebook {
namespace react {

class JSIExecutor : public JSExecutor {
    
public:
    JSIExecutor(
        std::shared_ptr<jsi::Runtime> runtime,
        std::shared_ptr<ExecutorDelegate> delegate,
        Logger logger,
        const JSIScopedTimeoutInvoker& timeoutInvoker,
        RuntimeInstaller runtimeInstaller);
    
};
    
}
}

#endif /* JSIExecutor_hpp */
