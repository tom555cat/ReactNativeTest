//
//  JSExecutor.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/12.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#ifndef JSExecutor_hpp
#define JSExecutor_hpp

#include <stdio.h>
#include <folly/dynamic.h>

namespace facebook {
namespace react {

class ModuleRegistry;
class JSExecutor;
    
// 从JS调用Navtive Code的接口类
class ExecutorDelegate {
public:
    virtual ~ExecutorDelegate() {}
    
    virtual std::shared_ptr<ModuleRegistry> getModuleRegistry() = 0;
    
    virtual void callNativeModules(
      JSExecutor& executor, folly::dynamic&& calls, bool isEndOfBatch) = 0;
    virtual MethodCallResult callSerializableNativeHook(
      JSExecutor& executor, unsigned int moduleId, unsigned int methodId, folly::dynamic&& args) = 0;
};
    
class RN_EXPORT JSExecutor {
    
};

}
}
#endif /* JSExecutor_hpp */
