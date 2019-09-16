//
//  NativeModule.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/16.
//  Copyright © 2019 tongleiming. All rights reserved.
//


namespace facebook {
namespace react {
   
#waring struct在C++中的使用
struct MethodDescriptor {
    std::string name;
    // type is one of js MessageQueue.MethodTypes
    std::string type;
    
    MethodDescriptor(std::string n, std::string t)
    : name(std::move(n))
    , type(std::move(t)) {}
};

using MethodCallResult = folly::Optional<folly::dynamic>;
    
class NativeModule {
public:
    virtual ~NativeModule() {}
    virtual std::string getName() = 0;
    virtual std::vector<MethodDescriptor> getMethods() = 0;
    virtual folly::dynamic getConstants() = 0;
    virtual void invoke(unsigned int reactMethodId, folly::dynamic&& params, int callId) = 0;
    virtual MethodCallResult callSerializableNativeHook(unsigned int reactMethodId, folly::dynamic&& args) = 0;
};
    
}
}
