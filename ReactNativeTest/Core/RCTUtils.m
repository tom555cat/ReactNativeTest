//
//  RCTUtils.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/29.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

RCT_EXTERN NSString *RCTDropReactPrefixes(NSString *s)
{
    if ([s hasPrefix:@"RK"]) {
        return [s substringFromIndex:2];
    } else if ([s hasPrefix:@"RCT"]) {
        return [s substringFromIndex:3];
    }
    
    return s;
}

BOOL RCTIsMainQueue()
{
    static void *mainQueueKey = &mainQueueKey;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        dispatch_queue_set_specific(dispatch_get_main_queue(),
                                    mainQueueKey, mainQueueKey, NULL);
    });
    return dispatch_get_specific(mainQueueKey) == mainQueueKey;
}

// Please do not use this method
// unless you know what you are doing.
void RCTUnsafeExecuteOnMainQueueSync(dispatch_block_t block)
{
    if (RCTIsMainQueue()) {
        block();
    } else {
        dispatch_sync(dispatch_get_main_queue(), ^{
            block();
        });
    }
}
