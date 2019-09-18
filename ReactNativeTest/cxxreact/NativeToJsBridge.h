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
    
    
class NativeToJsBridge {
public:
    NativeToJsBridge(
                     JSExecutorFactory* jsExecutorFactory,
                     std::shared_ptr<ModuleRegistry> registry,
                     std::shared_ptr<MessageQueueThread> jsQueue,
                     std::shared_ptr<InstanceCallback> callback);
    virtual ~NativeToJsBridge();
    
private:
#warning 通过m_destroyed是如何避免新增的任务在当前类析构之后然后由加入进来了
    std::shared_ptr<bool> m_destroyed;
    std::shared_ptr<JsToNativeBridge> m_delegate;
};
    
}
}
