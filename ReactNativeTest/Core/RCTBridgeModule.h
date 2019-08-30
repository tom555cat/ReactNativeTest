//
//  RCTBridgeModule.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/28.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

#import "RCTDefines.h"



/**
 每一个提供原生方法的类都遵守了这个协议
 */
@protocol RCTBridgeModule <NSObject>

// +load方法的目的是在加载阶段就将你的module通过bridge进行注册。
// +moduleName是为你的module起一个名字，如果没有的话，就是你定义的类的名字
// 还有一个是将方法名连起来的。。。。

--- +moduleName方法起什么作用，用在什么地方？
--- +load方法起什么作用，用在什么地方？

#define RCT_EXPORT_MODULE(js_name) \
RCT_EXTERN void RCTRegisterModule(Class); \
+ (NSString *)moduleName { return @#js_name; } \
+ (void)load { RCTRegisterModule(self); }

#define RCT_EXPORT_MODULE_NO_LOAD(js_name, objc_name) \
RCT_EXTERN void RCTRegisterModule(Class); \
+ (NSString *)moduleName { return @#js_name; } \
__attribute__((constructor)) static void \
RCT_CONCAT(initialize_, objc_name)() { RCTRegisterModule([objc_name class]); }

#define RCT_EXPORT_PRE_REGISTERED_MODULE(js_name) \
+ (NSString *)moduleName { return @#js_name; }

// Implemented by RCT_EXPORT_MODULE
+ (NSString *)moduleName;

@optional

// 给module提供的bridge接口，module要使用bridge的话需要使用"@synthesize bridge = _bridge。"
// 当要发送事件的时候会使用bridge。
// 当bridge初始化module的时候，会设置这个值？？？？？？
@property (nonatomic, weak, readonly) RCTBridge *bridge;



@end
