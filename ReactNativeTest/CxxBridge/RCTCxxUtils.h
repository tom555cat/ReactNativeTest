//
//  RCTCxxUtils.hpp
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#include <functional>
#include <memory>

#import <Foundation/Foundation.h>

namespace facebook {
namespace react {
    
class Instance;
class NativeModule;

// 从moduleData和bridge中创建出NativeModule(RCTNativeModule)，又一层封装
std::vector<std::unique_ptr<NativeModule>> createNativeModules(NSArray<RCTModuleData *> *modules, RCTBridge *bridge, const std::shared_ptr<Instance> &instance);

// function类模板可以存储任何可被调用的目标，包括函数，lambda表达式，绑定表达式或其他函数对象，以及
// 指向函数成员和指向数据成员的指针
NSError *tryAndReturnError(const std::function<void()>& func);
NSString *deriveSourceURL(NSURL *url);
    
} }
