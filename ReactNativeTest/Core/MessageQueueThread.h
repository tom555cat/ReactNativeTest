//
//  MessageQueueThread.hpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#pragma once

#include <condition_variable>
#include <functional>
#include <mutex>

namespace facebook {
namespace react {
    
class MessageQueueThread {
public:
    virtual ~MessageQueueThread() {}
    virtual void runOnQueue(std::function<void()>&&) = 0;
    // runOnQueueSync and quitSynchronous are dangerous.  They should only be
    // used for initialization and cleanup.
    virtual void runOnQueueSync(std::function<void()>&&) = 0;
    // Once quitSynchronous() returns, no further work should run on the queue.
    virtual void quitSynchronous() = 0;
};
    
}}
