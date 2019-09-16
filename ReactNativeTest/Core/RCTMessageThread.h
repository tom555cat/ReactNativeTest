//
//  RCTMessageThread.hpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCTJavaScriptExecutor.h"

#include "MessageQueueThread.h"

namespace facebook {
namespace react {

class RCTMessageThread : public MessageQueueThread {
public:
    RCTMessageThread(NSRunLoop *runLoop, RCTJavaScriptCompleteBlock errorBlock);
    ~RCTMessageThread() override;
    
private:
    void tryFunc(const std::function<void()>& func);
    void runAsync(std::function<void()> func);
    void runSync(std::function<void()> func);
    
    // 这个m_cfRunLoop持有的是jsThread的runLoop
    CFRunLoopRef m_cfRunLoop;
    // 这个错误回调时创建RCTMessageThread提供的错误回调
    RCTJavaScriptCompleteBlock m_errorBlock;
    std::atomic_bool m_shutdown;
};
    
    
}
}
