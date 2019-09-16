//
//  RCTMessageThread.cpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#include "RCTMessageThread.h"

namespace facebook {
namespace react {

// 构造函数
RCTMessageThread::RCTMessageThread(NSRunLoop *runLoop, RCTJavaScriptCompleteBlock errorBlock)
    : m_cfRunLoop([runLoop getCFRunLoop])
    , m_errorBlock(errorBlock)
    , m_shutdown(false) {
#warning 在构造函数中从ARC到C++，自己维护了生命周期
    CFRetain(m_cfRunLoop);
}
    
RCTMessageThread::~RCTMessageThread() {
#warning 在构造函数中从ARC到C++，自己维护了生命周期
    CFRelease(m_cfRunLoop);
}
    
void RCTMessageThread::runOnQueueSync(std::function<void()>&& func) {
    if (m_shutdown) {
        return;
    }
    runSync([this, func=std::move(func)] {
        if (!m_shutdown) {
            tryFunc(func);
        }
    });
}
    
// This is analogous to dispatch_sync
void RCTMessageThread::runSync(std::function<void()> func) {
    if (m_cfRunLoop == CFRunLoopGetCurrent()) {
        func();
        return;
    }
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    runAsync([func=std::make_shared<std::function<void()>>(std::move(func)), &sema] {
        (*func)();
        dispatch_semaphore_signal(sema);
    });
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
}
    
// This is analogous to dispatch_async
#warning 异步地执行一个任务，难道就是这个样子？
void RCTMessageThread::runAsync(std::function<void()> func) {
    CFRunLoopPerformBlock(m_cfRunLoop, kCFRunLoopCommonModes, ^{ func(); });
    CFRunLoopWakeUp(m_cfRunLoop);
}

    
}
}
