//
//  RCTCxxUtils.cpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#include "RCTCxxUtils.h"

namespace facebook {
namespace react {
    
    
std::vector<std::unique_ptr<NativeModule>> createNativeModules(NSArray<RCTModuleData *> *modules, RCTBridge *bridge, const std::shared_ptr<Instance> &instance)
{
    std::vector<std::unique_ptr<NativeModule>> nativeModules;
    for (RCTModuleData *moduleData in modules) {
        // 判断是不是C++的native module，目前没有实现C++的module
        if ([moduleData.moduleClass isSubclassOfClass:[RCTCxxModule class]]) {
            nativeModules.emplace_back(std::make_unique<CxxNativeModule>(
                                                                         instance,
                                                                         [moduleData.name UTF8String],
                                                                         [moduleData] { return [(RCTCxxModule *)(moduleData.instance) createModule]; },
                                                                         std::make_shared<DispatchMessageQueueThread>(moduleData)));
        } else {
            // emplace_back相当于push_back
            nativeModules.emplace_back(std::make_unique<RCTNativeModule>(bridge, moduleData));
        }
    }
    return nativeModules;
}
    
    
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
    
}
}


