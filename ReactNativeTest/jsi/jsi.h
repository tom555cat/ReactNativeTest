//
//  jsi.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//


namespace facebook {
namespace jsi {

class Pointer;
class Object;
    
class Runtime {
public:
    virtual ~Runtime();
    
    /// Evaluates the given JavaScript \c buffer. \c sourceURL is used
    /// to annonate
    /// Evaluetes给定的JS buffer.
    /// sourceURL用来annotate the stack trace如果有一个异常的话。
    /// 内容可能是utf8-encoded JS源码，或者是二进制字节码(某种格式的实现)。
    /// 如果输入的格式是不知道的，或者evaluation出现错误，会产生一个
    /// JSIExeception异常。
    virtual void evaluateJavaScript(
        std::unique_ptr<const Buffer> buffer,
        const std::string& sourceURL) = 0;
    
    /// \return the global object
    /// 返回全局对象
    virtual Object global() = 0;
    
protected:
    struct PointerValue {
        virtual void invalidate() = 0;
        
    protected:
        ~PointerValue() = default;
    };
    
    // 创建对象的方法
    virtual Object createObject() = 0;
    
    virtual Value getProperty(const Object&, const PropNameID& name) = 0;
    virtual Value getProperty(const Object&, const String& name) = 0;
};
    
// Base class for pointer-storing types
class Pointer {
};
    
class String : public Pointer {
};

/// 一个JS对象在原生端的容器
class Object : public Pointer {
public:
    /// \return the property of the object with the given ascii name.
    /// If the name isn't a property on the object, returns the
    /// undefined value.
    // 获取对象的属性
    Value getProperty(Runtime& runtime, const char* name) const;
    
    /// \return the property of the object with the String name.
    /// If the name isn't a property on the object, returns the
    /// undefined value.
    // 获取对象的属性
    Value getProperty(Runtime& runtime, const String& name) const;
    
    /// \return same as \c getProperty(name).asObject(), except with
    /// a better exception message.
    Object getPropertyAsObject(Runtime& runtime, const char* name) const;
    
    /// \return similar to \c
    /// getProperty(name).getObject().getFunction(), except it will
    /// throw JSIException instead of asserting if the property is
    /// not an object, or the object is not callable.
    Function getPropertyAsFunction(Runtime& runtime, const char* name) const;
};

/// Represents a JS Object which is guaranteed to be Callable.
class Function : public Object {
public:
    Function(Function &&) = default;
    Function& operator=(Function&&) = default;
    
    /// Calls the function with \c count \c args.  The \c this value of
    /// the JS function will be undefined.
    Value call(Runtime& runtime, const Value* args, size_t count) const;
    
    /// Calls the function with any number of arguments similarly to
    /// Object::setProperty().  The \c this value of the JS function
    /// will be undefined.
    template <typename... Args>
    Value call(Runtime& runtime, Args&&... args) const;
};
    
class Value {
    
};
    
}
}
