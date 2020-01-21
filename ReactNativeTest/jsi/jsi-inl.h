//
//  jsi-inl.h
//  ReactNativeTest
//
//  Created by tongleiming on 2020/1/20.
//  Copyright © 2020 tongleiming. All rights reserved.
//

namespace facebook {
namespace jsi {
namespace detail {
    
inline Value Object::getProperty(Runtime& runtime, const char* name) const {
    return getProperty(runtime, String::createFromAscii(runtime, name));
}

inline Value Object::getProperty(Runtime& runtime, const String& name) const {
    return runtime.getProperty(*this, name);
}

inline Value Object::getProperty(Runtime& runtime, const PropNameID& name)
const {
    return runtime.getProperty(*this, name);
}
    
template <typename... Args>
inline Value Function::call(Runtime& runtime, Args&&... args) const {
    // A more awesome version of this would be able to create raw values
    // which can be used directly as HermesValues, instead of having to
    // wrap the args in Values and hvFromValue on each to unwrap them.
    // But this will do for now.
    // 调用了👇那个call函数
    return call(runtime, {detail::toValue(runtime, std::forward<Args>(args))...});
}

inline Value Function::call(Runtime& runtime, const Value* args, size_t count)
const {
    return runtime.call(*this, Value::undefined(), args, count);
}
    
}}}
