//
//  RCTCxxUtils.cpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#include "RCTCxxUtils.h"

NSError *tryAndReturnError(const std::function<void()>& func)
{
    try {
        @try {
            func();
            return nil;
        }
        @catch (NSException *exception) {
            NSString *message =
            [NSString stringWithFormat:@"Exception '%@' was thrown from JS thread", exception];
            return RCTErrorWithMessage(message);
        }
        @catch (id exception) {
            // This will catch any other ObjC exception, but no C++ exceptions
            return RCTErrorWithMessage(@"non-std ObjC Exception");
        }
    } catch (const std::exception &ex) {
        return errorWithException(ex);
    } catch (...) {
        // On a 64-bit platform, this would catch ObjC exceptions, too, but not on
        // 32-bit platforms, so we catch those with id exceptions above.
        return RCTErrorWithMessage(@"non-std C++ exception");
    }
}
