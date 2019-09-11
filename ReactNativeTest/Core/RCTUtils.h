//
//  RCTUtils.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/29.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#ifndef RCTUtils_h
#define RCTUtils_h

#include "RCTDefines.h"
#include <Foundation/Foundation.h>

// Given a string, drop common RN prefixes (RCT, RK, etc.)
RCT_EXTERN NSString *RCTDropReactPrefixes(NSString *s);

// 判断目前是否是在主队列上(不是判断是否在主线程上，两个不一样)
RCT_EXTERN BOOL RCTIsMainQueue(void);

// Legacy function to execute the specified block on the main queue synchronously.
// Please do not use this unless you know what you're doing.
RCT_EXTERN void RCTUnsafeExecuteOnMainQueueSync(dispatch_block_t block);

#endif /* RCTUtils_h */
