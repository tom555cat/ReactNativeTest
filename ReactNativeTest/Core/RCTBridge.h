//
//  RCTBridge.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/27.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RCTPerformanceLogger.h"
#import "RCTBridgeModule.h"
#import "RCTDefines.h"

@protocol RCTBridgeDelegate;

/**
 * This notification fires when the bridge initializes.
 */
RCT_EXTERN NSString *const RCTJavaScriptWillStartLoadingNotification;

NS_ASSUME_NONNULL_BEGIN

typedef NSArray<id<RCTBridgeModule>> *(^RCTBridgeModuleListProvider)(void);

@interface RCTBridge : NSObject

// 在bridge初始化的过程中提供了delegate
@property (nonatomic, weak, readonly) id<RCTBridgeDelegate> delegate;

// 加载Script的地址
@property (nonatomic, strong, readonly) NSURL *bundleURL;

#warning 只是说是executor的class，暂时没有更多细节信息
@property (nonatomic, strong) Class executorClass;

@property (nonatomic, copy, readonly) NSDictionary *launchOptions;

/**
 * Use this to check if the bridge is currently loading.
 */
@property (nonatomic, readonly, getter=isLoading) BOOL loading;

/**
 * Use this to check if the bridge has been invalidated.
 */
@property (nonatomic, readonly, getter=isValid) BOOL valid;

#warning 日志库，可能值得单独看
@property (nonatomic, readonly, strong) RCTPerformanceLogger *performanceLogger;

// 是通过RCTCxxBridge创建出来的bridge
@property (atomic, strong) RCTBridge *batchedBridge;

// 入口
#warning block和launchOptions提供什么参数?
- (instancetype)initWithBundleURL:(NSURL *)bundleURL
                   moduleProvider:(RCTBridgeModuleListProvider)block
                    launchOptions:(NSDictionary *)launchOptions;

- (instancetype)initWithDelegate:(id<RCTBridgeDelegate>)delegate
                       bundleURL:(NSURL *)bundleURL
                  moduleProvider:(RCTBridgeModuleListProvider)block
                   launchOptions:(NSDictionary *)launchOptions;

@end

NS_ASSUME_NONNULL_END
