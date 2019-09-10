//
//  RCTModuleData.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/4.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTModuleData.h"

@implementation RCTModuleData
{
    __weak RCTBridge *_bridge;
    RCTBridgeModuleProvider _moduleProvider;
    
}

- (instancetype)initWithModuleClass:(Class)moduleClass
                             bridge:(RCTBridge *)bridge
{
    return [self initWithModuleClass:moduleClass
                      moduleProvider:^id<RCTBridgeModule>{ return [moduleClass new]; }
                              bridge:bridge];
}

- (instancetype)initWithModuleClass:(Class)moduleClass
                     moduleProvider:(RCTBridgeModuleProvider)moduleProvider
                             bridge:(RCTBridge *)bridge
{
    if (self = [super init]) {
        _bridge = bridge;
        _moduleClass = moduleClass;
        _moduleProvider = [moduleProvider copy];
        [self setUp];
    }
    return self;
}

- (void)setUp
{
#warning batchDidComplete方法在一般的module中不会实现，但是RCTUIManager实现了这个方法。后续看。
    _implementsBatchDidComplete = [_moduleClass instancesRespondToSelector:@selector(batchDidComplete)];
    _implementsPartialBatchDidFlush = [_moduleClass instancesRespondToSelector:@selector(partialBatchDidFlush)];
    
    // If a module overrides `constantsToExport` and doesn't implement `requiresMainQueueSetup`, then we must assume
    // that it must be called on the main thread, because it may need to access UIKit.
    _hasConstantsToExport = [_moduleClass instancesRespondToSelector:@selector(constantsToExport)];
    
    const BOOL implementsRequireMainQueueSetup = [_moduleClass respondsToSelector:@selector(requiresMainQueueSetup)];
    if (implementsRequireMainQueueSetup) {
#warning 方便起见，假设所有module都选择在主线程上进行setup
        _requiresMainQueueSetup = [_moduleClass requiresMainQueueSetup];
    } else {
        static IMP objectInitMethod;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            objectInitMethod = [NSObject instanceMethodForSelector:@selector(init)];
        });
        
        // If a module overrides `init` then we must assume that it expects to be
        // initialized on the main thread, because it may need to access UIKit.
        const BOOL hasCustomInit = !_instance && [_moduleClass instanceMethodForSelector:@selector(init)] != objectInitMethod;
        
        _requiresMainQueueSetup = _hasConstantsToExport || hasCustomInit;
        if (_requiresMainQueueSetup) {
            const char *methodName = "";
            if (_hasConstantsToExport) {
                methodName = "constantsToExport";
            } else if (hasCustomInit) {
                methodName = "init";
            }
            RCTLogWarn(@"Module %@ requires main queue setup since it overrides `%s` but doesn't implement "
                       "`requiresMainQueueSetup`. In a future release React Native will default to initializing all native modules "
                       "on a background thread unless explicitly opted-out of.", _moduleClass, methodName);
        }
    }
}

@end
