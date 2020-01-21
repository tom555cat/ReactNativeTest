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
    
// * runtime是facebook::jsc::makeJSCRuntime()
// * delegate，是cxxBridge
// * logger，可以忽略掉
// * scopedTimeoutInvoker，是JSIExecutor::defaultTimeoutInvoker
// * runtimeInstaller，这个参数应该是传递了个空
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
    
void JSIExecutor::bindBridge() {
    std::call_once(bindFlag_, [this] {
        SystraceSection s("JSIExecutor::bindBridge (once)");
        // runtime_->global()是获取ctx的全局对象，
        // 然后获取全局对象上的"__fbBatchedBridge"属性，
        Value batchedBridgeValue =
        runtime_->global().getProperty(*runtime_, "__fbBatchedBridge");
        if (batchedBridgeValue.isUndefined()) {
            Function requireBatchedBridge = runtime_->global().getPropertyAsFunction(
                                                                                     *runtime_, "__fbRequireBatchedBridge");
            // call函数实际调用了runtime_的call函数(JSCRuntime::call)
            batchedBridgeValue = requireBatchedBridge.call(*runtime_);
            if (batchedBridgeValue.isUndefined()) {
                throw JSINativeException(
                                         "Could not get BatchedBridge, make sure your bundle is packaged correctly");
            }
        }
        
        // 将JS执行结果作为了原生端JS对象
        Object batchedBridge = batchedBridgeValue.asObject(*runtime_);
        // 获取JS对象的callFunctionReturnFlushedQueue属性，该属性是个可调用的函数
        callFunctionReturnFlushedQueue_ = batchedBridge.getPropertyAsFunction(
                                                                              *runtime_, "callFunctionReturnFlushedQueue");
        invokeCallbackAndReturnFlushedQueue_ = batchedBridge.getPropertyAsFunction(
                                                                                   *runtime_, "invokeCallbackAndReturnFlushedQueue");
        flushedQueue_ =
        batchedBridge.getPropertyAsFunction(*runtime_, "flushedQueue");
        callFunctionReturnResultAndFlushedQueue_ =
        batchedBridge.getPropertyAsFunction(
                                            *runtime_, "callFunctionReturnResultAndFlushedQueue");
    });
}

    
// 调用JS代码
void JSIExecutor::callFunction(
                               const std::string& moduleId,
                               const std::string& methodId,
                               const folly::dynamic& arguments) {
    SystraceSection s(
                      "JSIExecutor::callFunction", "moduleId", moduleId, "methodId", methodId);
    if (!callFunctionReturnFlushedQueue_) {
        bindBridge();
    }
    
    // Construct the error message producer in case this times out.
    // This is executed on a background thread, so it must capture its parameters
    // by value.
    auto errorProducer = [=] {
        std::stringstream ss;
        ss << "moduleID: " << moduleId << " methodID: " << methodId
        << " arguments: " << folly::toJson(arguments);
        return ss.str();
    };
    
    // callFunctionReturnFlushedQueue_是个JS函数，是可调用的。
    Value ret = Value::undefined();
    try {
        scopedTimeoutInvoker_(
          [&] {
              ret = callFunctionReturnFlushedQueue_->call(
                  *runtime_,
                  moduleId,
                  methodId,
                  valueFromDynamic(*runtime_, arguments));
          },
          std::move(errorProducer));
    } catch (...) {
        std::throw_with_nested(
            std::runtime_error("Error calling " + moduleId + "." + methodId));
    }
    
    callNativeModules(ret, true);
}
    
}
}
