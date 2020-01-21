//
//  jsi.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "jsi.h"

namespace facebook {
namespace jsi {
    
namespace detail {
    
void throwJSError(Runtime& rt, const char* msg) {
    throw JSError(rt, msg);
}
    
} // namespace detail
    
Object Object::getPropertyAsObject(Runtime& runtime, const char* name) const {
    Value v = getProperty(runtime, name);
    
    if (!v.isObject()) {
        throw JSError(
                      runtime,
                      std::string("getPropertyAsObject: property '") + name +
                      "' is not an Object");
    }
    
    return v.getObject(runtime);
}
    
Function Object::getPropertyAsFunction(Runtime& runtime, const char* name)
const {
    Object obj = getPropertyAsObject(runtime, name);
    if (!obj.isFunction(runtime)) {
        throw JSError(
                      runtime,
                      std::string("getPropertyAsFunction: property '") + name +
                      "' is not a Function");
    };
    
    Runtime::PointerValue* value = obj.ptr_;
    obj.ptr_ = nullptr;
    return Function(value);
}

    
    
}}
