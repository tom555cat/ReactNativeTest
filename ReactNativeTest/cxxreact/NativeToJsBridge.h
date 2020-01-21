//
//  NativeToJsBridge.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include <memory>

namespace facebook {
namespace react {
    
struct InstanceCallback;
class ModuleRegistry;
class MessageQueueThread;
class JsToNativeBridge;
    
// 这个类用来管理native代码调用JS。它页管理着executors和它们的线程。
// executor -> thread
// 这里所有的函数可以从任意线程调用
    
// 除了loadApplicationScriptSync()，所有的返回void的方法都加入ctor的jsQueue中，并且立即返回。
    
class NativeToJsBridge {
public:
    NativeToJsBridge(
                     JSExecutorFactory* jsExecutorFactory,
                     std::shared_ptr<ModuleRegistry> registry,
                     std::shared_ptr<MessageQueueThread> jsQueue,
                     std::shared_ptr<InstanceCallback> callback);
    virtual ~NativeToJsBridge();
    
    /**
     * Executes a function with the module ID and method ID and any additional
     * arguments in JS.
     */
    // 在JS中通过制定module ID和method ID和其他参数。
    void callFunction(std::string&& module, std::string&& method, folly::dynamic&& args);
    
private:
    // 在callFunction内部调用了runOnExecutorQueue函数
    void runOnExecutorQueue(std::function<void(JSExecutor*)> task);
    
#warning 通过m_destroyed是如何避免新增的任务在当前类析构之后然后由加入进来了
    std::shared_ptr<bool> m_destroyed;
    // 通过保存了ModuleRegistry和cxxBridge实现JS调用原生；
    // 这个代理是RN调用原生的代理；
    std::shared_ptr<JsToNativeBridge> m_delegate;
    // cxxBridge中用空参数创建的一个"std::make_shared<JSCExecutorFactory>(nullptr)，
    // 然后利用这个JSCExecutorFactory创建了JSIExecutor赋值给了m_executor
    std::unique_ptr<JSExecutor> m_executor;
    // 通过构造函数初始化而来，是CxxBridge的属性"std::shared_ptr<RCTMessageThread> _jsMessageThread;"
    // 传递过来的。
    std::shared_ptr<MessageQueueThread> m_executorMessageQueueThread;
};
    
}
}
