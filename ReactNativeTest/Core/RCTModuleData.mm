//
//  RCTModuleData.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/4.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTModuleData.h"
#include <mutex>

@implementation RCTModuleData
{
    __weak RCTBridge *_bridge;
    // _moduleProvider是一个^id<RCTBridgeModule>{ return [moduleClass new]; }  block
    RCTBridgeModuleProvider _moduleProvider;
    
#warning 在Objective-C的实例变量中使用C++的变量
    std::mutex _instanceLock;
    BOOL _setupComplete;
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

@synthesize methodQueue = _methodQueue;

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
#warning 方便起见，假设所有module都选择在主队列上进行setup
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

#pragma mark - private setup methods

- (void)setUpInstanceAndBridge
{
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData setUpInstanceAndBridge]", @{
                                                                                              @"moduleClass": NSStringFromClass(_moduleClass)
                                                                                              });
    {
        std::unique_lock<std::mutex> lock(_instanceLock);
        
        if (!_setupComplete && _bridge.valid) {
            if (!_instance) {
                if (RCT_DEBUG && _requiresMainQueueSetup) {
                    RCTAssertMainQueue();
                }
                RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData setUpInstanceAndBridge] Create module", nil);
                // 执行这个block创建module class对应的实例。
                _instance = _moduleProvider ? _moduleProvider() : nil;
                RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
                if (!_instance) {
                    // Module init returned nil, probably because automatic instantatiation
                    // of the module is not supported, and it is supposed to be passed in to
                    // the bridge constructor. Mark setup complete to avoid doing more work.
                    _setupComplete = YES;
                    RCTLogWarn(@"The module %@ is returning nil from its constructor. You "
                               "may need to instantiate it yourself and pass it into the "
                               "bridge.", _moduleClass);
                }
            }
            
            if (_instance && RCTProfileIsProfiling()) {
                RCTProfileHookInstance(_instance);
            }
            
            // Bridge must be set before methodQueue is set up, as methodQueue
            // initialization requires it (View Managers get their queue by calling
            // self.bridge.uiManager.methodQueue)
#warning instance设置bridge
            [self setBridgeForInstance];
        }
#warning 创建methodQueue需要module instance的bridge是设置好的
        [self setUpMethodQueue];
    }
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    
    // This is called outside of the lock in order to prevent deadlock issues
    // because the logic in `finishSetupForInstance` can cause
    // `moduleData.instance` to be accessed re-entrantly.
    
    // 在所有module的instance创建完之后_bridge.moduleSetupComplete才会设置为YES
#warning 那么既然一般来说instance创建之后才会设置_bridge.moduleSetupComplete，那么什么情况下才会走到这里。
#warning 打断点发现，所有module在创建instance的时候_bridge.moduleSetupComplete已经设置为YES。
    if (_bridge.moduleSetupComplete) {
        [self finishSetupForInstance];
    } else {
        // If we're here, then the module is completely initialized,
        // except for what finishSetupForInstance does.  When the instance
        // method is called after moduleSetupComplete,
        // finishSetupForInstance will run.  If _requiresMainQueueSetup
        // is true, getting the instance will block waiting for the main
        // thread, which could take a while if the main thread is busy
        // (I've seen 50ms in testing).  So we clear that flag, since
        // nothing in finishSetupForInstance needs to be run on the main
        // thread.
        _requiresMainQueueSetup = NO;
    }
}

// 给module instance的bridge属性赋值
- (void)setBridgeForInstance
{
    // moduel遵循了RCTBridgeModule这个协议，这个协议里有bridge属性
    if ([_instance respondsToSelector:@selector(bridge)] && _instance.bridge != _bridge) {
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData setBridgeForInstance]", nil);
        @try {
            [(id)_instance setValue:_bridge forKey:@"bridge"];
        }
        @catch (NSException *exception) {
            RCTLogError(@"%@ has no setter or ivar for its bridge, which is not "
                        "permitted. You must either @synthesize the bridge property, "
                        "or provide your own setter method.", self.name);
        }
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    }
}

- (void)finishSetupForInstance
{
    if (!_setupComplete && _instance) {
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData finishSetupForInstance]", nil);
        _setupComplete = YES;
        [_bridge registerModuleForFrameUpdates:_instance withModuleData:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:RCTDidInitializeModuleNotification
                                                            object:_bridge
                                                          userInfo:@{@"module": _instance, @"bridge": RCTNullIfNil(_bridge.parentBridge)}];
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    }
}

- (void)setUpMethodQueue
{
    if (_instance && !_methodQueue && _bridge.valid) {
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData setUpMethodQueue]", nil);
        BOOL implementsMethodQueue = [_instance respondsToSelector:@selector(methodQueue)];
        if (implementsMethodQueue && _bridge.valid) {
            _methodQueue = _instance.methodQueue;
        }
        
        // 如果你自己在methodQueue中定义的队列创建失败，那么RN还会为你创建一个队列。
        if (!_methodQueue && _bridge.valid) {
            // Create new queue (store queueName, as it isn't retained by dispatch_queue)
            _queueName = [NSString stringWithFormat:@"com.facebook.react.%@Queue", self.name];
            _methodQueue = dispatch_queue_create(_queueName.UTF8String, DISPATCH_QUEUE_SERIAL);
            
            // assign it to the module
            if (implementsMethodQueue) {
                @try {
                    [(id)_instance setValue:_methodQueue forKey:@"methodQueue"];
                }
                @catch (NSException *exception) {
                    RCTLogError(@"%@ is returning nil for its methodQueue, which is not "
                                "permitted. You must either return a pre-initialized "
                                "queue, or @synthesize the methodQueue to let the bridge "
                                "create a queue for you.", self.name);
                }
            }
        }
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    }
}


#pragma mark - public getters

- (BOOL)hasInstance {
#warning 这种使用锁的方式比NSLock有哪些好处?
#warning NSLock需要lock和unlock，比起来更简单；效率上呢？
    std::unique_lock<std::mutex> lock(_instanceLock);
    return _instance != nil;
}

- (id<RCTBridgeModule>)instance
{
    if (!_setupComplete) {
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, ([NSString stringWithFormat:@"[RCTModuleData instanceForClass:%@]", _moduleClass]), nil);
        if (_requiresMainQueueSetup) {
            // The chances of deadlock here are low, because module init very rarely
            // calls out to other threads, however we can't control when a module might
            // get accessed by client code during bridge setup, and a very low risk of
            // deadlock is better than a fairly high risk of an assertion being thrown.
            RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"[RCTModuleData instance] main thread setup", nil);
            
            if (!RCTIsMainQueue()) {   // 要在主队列上初始化，如果当前不是主队列，则报个警
                RCTLogWarn(@"RCTBridge required dispatch_sync to load %@. This may lead to deadlocks", _moduleClass);
            }
            
            // 将任务添加到主线程上，这个函数可能不太安全，为什么不判断线程呢?
            RCTUnsafeExecuteOnMainQueueSync(^{
                [self setUpInstanceAndBridge];
            });
            RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
        } else {
            [self setUpInstanceAndBridge];
        }
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    }
    return _instance;
}



@end
