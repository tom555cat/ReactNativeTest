//
//  RCTBridge+Private.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/27.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTBridge.h"

NS_ASSUME_NONNULL_BEGIN

#warning 使用了extension，extension中保存了RCTBridge的私有属性和方法，使用方式和目的完全遵守extension的定义。
@interface RCTBridge ()


@property (nonatomic, copy, readonly) RCTBridgeModuleListProvider moduleProvider;

// 声明一个私有方法，在bridge的子类，即cxxBridge上调用，运行executor，开始loading
// 当前类没有实现，只有子类cxxBridge实现了。
- (void)start;

@end

@interface RCTCxxBridge : RCTBridge

@property (nonatomic) void *runtime;

- (instancetype)initWithParentBridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
