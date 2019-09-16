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
    
}
}
