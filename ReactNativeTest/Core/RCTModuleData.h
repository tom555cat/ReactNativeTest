//
//  RCTModuleData.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/4.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RCTBridgeModule;
@class RCTBridge;

typedef id<RCTBridgeModule>(^RCTBridgeModuleProvider)(void);

@interface RCTModuleData : NSObject

- (instancetype)initWithModuleClass:(Class)moduleClass
                             bridge:(RCTBridge *)bridge;

- (instancetype)initWithModuleClass:(Class)moduleClass
                     moduleProvider:(RCTBridgeModuleProvider)moduleProvider
                             bridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithModuleInstance:(id<RCTBridgeModule>)instance
                                bridge:(RCTBridge *)bridge NS_DESIGNATED_INITIALIZER;

@property (nonatomic, strong, readonly) Class moduleClass;


/**
 * Returns the current module instance. Note that this will init the instance
 * if it has not already been created. To check if the module instance exists
 * without causing it to be created, use `hasInstance` instead.
 */
// 通过moduleClass创建的实例
@property (nonatomic, strong, readwrite) id<RCTBridgeModule> instance;


/**
 * Whether the receiver has a valid `instance` which implements -batchDidComplete.
 */
// module是否实现了实例方法-batchDidComplete
@property (nonatomic, assign, readonly) BOOL implementsBatchDidComplete;

/**
 * Whether the receiver has a valid `instance` which implements
 * -partialBatchDidFlush.
 */
// module是否实现了实例方法-partialBatchDidFlush
@property (nonatomic, assign, readonly) BOOL implementsPartialBatchDidFlush;

/**
 * Returns YES if module has constants to export.
 */
// module是否实现了实例方法-constantsToExport
// -constantsToExport方法长这样:
//- (NSDictionary *)constantsToExport
//{
//    return @{
//             @"VERSION": @1,
//             };
//}
@property (nonatomic, assign, readonly) BOOL hasConstantsToExport;

/**
 * Returns YES if module instance must be created on the main thread.
 */
// 根据module实现的+requiresMainQueueSetup方法返回的值来判断是否需要在主线程执行
@property (nonatomic, assign) BOOL requiresMainQueueSetup;

@end

NS_ASSUME_NONNULL_END
