//
//  RCTCxxBridge.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/27.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTBridge+Private.h"
#import "RCTBridge.h"
#import "RCTBridgeDelegate.h"
#import "RCTModuleData.h"

@interface RCTCxxBridge ()

// 居然还弱引用了父类
@property (nonatomic, weak, readonly) RCTBridge *parentBridge;

@end

@implementation RCTCxxBridge
{
    BOOL _moduleRegistryCreated;
    
    NSMutableArray<RCTPendingCall> *_pendingCalls;
    RCTDisplayLink *_displayLink;
    
    // Native modules
    // key为moduleName，value为
    NSMutableDictionary<NSString *, RCTModuleData *> *_moduleDataByName;
    // 里面是moduleData，是创建好的moduleData
    NSMutableArray<RCTModuleData *> *_moduleDataByID;
    // 里面是moduleClass，是在创建好moduleData之后，将moduleClass保存进了这个数组，应该是内部使用的
    NSMutableArray<Class> *_moduleClassesByID;
    
    // JS thread management
#warning 这个线程，什么内容跑在了这个线程上
    NSThread *_jsThread;
}

#warning 在子类RCTCxxBridge中干脆又实现了一套performanceLogger实例变量+读写方法
@synthesize performanceLogger = _performanceLogger;
@synthesize valid = _valid;
@synthesize loading = _loading;

- (instancetype)initWithParentBridge:(RCTBridge *)bridge
{
    RCTAssertParam(bridge);
    
    if ((self = [super initWithDelegate:bridge.delegate
                              bundleURL:bridge.bundleURL
                         moduleProvider:bridge.moduleProvider
                          launchOptions:bridge.launchOptions])) {
        _parentBridge = bridge;
        _performanceLogger = [bridge performanceLogger];
        
        registerPerformanceLoggerHooks(_performanceLogger);
        
        RCTLogInfo(@"Initializing %@ (parent: %@, executor: %@)", self, bridge, [self executorClass]);
        
        /**
         * Set Initial State
         */
        _valid = YES;
        _loading = YES;
        _moduleRegistryCreated = NO;
        _pendingCalls = [NSMutableArray new];
        _displayLink = [RCTDisplayLink new];
        _moduleDataByName = [NSMutableDictionary new];
        _moduleClassesByID = [NSMutableArray new];
        _moduleDataByID = [NSMutableArray new];
        
        [RCTBridge setCurrentBridge:self];
    }
    return self;
}

/**
 * Prevent super from calling setUp (that'd create another batchedBridge)
 */
#warning 防止陷入死循环，子类重写了setUp方法，里面什么都没有
- (void)setUp {}

- (void)start
{
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"-[RCTCxxBridge start]", nil);
    
    [[NSNotificationCenter defaultCenter]
     postNotificationName:RCTJavaScriptWillStartLoadingNotification
     object:_parentBridge userInfo:@{@"bridge": self}];
    
    // Set up the JS thread early
    _jsThread = [[NSThread alloc] initWithTarget:[self class]
                                        selector:@selector(runRunLoop)
                                          object:nil];
    _jsThread.name = RCTJSThreadName;
    _jsThread.qualityOfService = NSOperationQualityOfServiceUserInteractive;
#if RCT_DEBUG
    _jsThread.stackSize *= 2;
#endif
    [_jsThread start];
    
#warning 这里有一个group，是保证什么和什么同步？
    dispatch_group_t prepareBridge = dispatch_group_create();
    
    [_performanceLogger markStartForTag:RCTPLNativeModuleInit];
    
    // 查看是否通过其他方式提供了module
    [self registerExtraModules];
    
    // Initialize all native modules that cannot be loaded lazily
    // RCTGetModuleClasses()返回所有通过+load注册的class的数组
    (void)[self _initializeModules:RCTGetModuleClasses() withDispatchGroup:prepareBridge lazilyDiscovered:NO];
    [self registerExtraLazyModules];
    
    [_performanceLogger markStopForTag:RCTPLNativeModuleInit];
    
    // This doesn't really do anything.  The real work happens in initializeBridge.
    _reactInstance.reset(new Instance);
    
    __weak RCTCxxBridge *weakSelf = self;
    
    // Prepare executor factory (shared_ptr for copy into block)
    std::shared_ptr<JSExecutorFactory> executorFactory;
    if (!self.executorClass) {
        if ([self.delegate conformsToProtocol:@protocol(RCTCxxBridgeDelegate)]) {
            id<RCTCxxBridgeDelegate> cxxDelegate = (id<RCTCxxBridgeDelegate>) self.delegate;
            executorFactory = [cxxDelegate jsExecutorFactoryForBridge:self];
        }
        if (!executorFactory) {
            executorFactory = std::make_shared<JSCExecutorFactory>(nullptr);
        }
    } else {
        id<RCTJavaScriptExecutor> objcExecutor = [self moduleForClass:self.executorClass];
        executorFactory.reset(new RCTObjcExecutorFactory(objcExecutor, ^(NSError *error) {
            if (error) {
                [weakSelf handleError:error];
            }
        }));
    }
    
    // Dispatch the instance initialization as soon as the initial module metadata has
    // been collected (see initModules)
    dispatch_group_enter(prepareBridge);
    [self ensureOnJavaScriptThread:^{
     [weakSelf _initializeBridge:executorFactory];
     dispatch_group_leave(prepareBridge);
     }];
    
    // Load the source asynchronously, then store it for later execution.
    dispatch_group_enter(prepareBridge);
    __block NSData *sourceCode;
    [self loadSource:^(NSError *error, RCTSource *source) {
     if (error) {
     [weakSelf handleError:error];
     }
     
     sourceCode = source.data;
     dispatch_group_leave(prepareBridge);
     } onProgress:^(RCTLoadingProgress *progressData) {
#if RCT_DEV && __has_include("RCTDevLoadingView.h")
     // Note: RCTDevLoadingView should have been loaded at this point, so no need to allow lazy loading.
     RCTDevLoadingView *loadingView = [weakSelf moduleForName:RCTBridgeModuleNameForClass([RCTDevLoadingView class])
                                        lazilyLoadIfNecessary:NO];
     [loadingView updateProgress:progressData];
#endif
     }];
    
    // Wait for both the modules and source code to have finished loading
    dispatch_group_notify(prepareBridge, dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
        RCTCxxBridge *strongSelf = weakSelf;
        if (sourceCode && strongSelf.loading) {
            [strongSelf executeSourceCode:sourceCode sync:NO];
        }
    });
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
}

// 只有在RCTBridgeModule中的代理方法或者moduleProvider才能提供额外的module，
// 暂时不看
- (void)registerExtraModules
{
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways,
                            @"-[RCTCxxBridge initModulesWithDispatchGroup:] extraModules", nil);
    
    // 遵守RCTBridgeModule的类只有module，所以extraModules也是一些modules
    NSArray<id<RCTBridgeModule>> *extraModules = nil;
    
    // 都为空，暂时忽略掉
    if ([self.delegate respondsToSelector:@selector(extraModulesForBridge:)]) {
        extraModules = [self.delegate extraModulesForBridge:_parentBridge];
    } else if (self.moduleProvider) {
        extraModules = self.moduleProvider();
    }
    
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    
#if RCT_DEBUG
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        RCTVerifyAllModulesExported(extraModules);
    });
#endif
    
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways,
                            @"-[RCTCxxBridge initModulesWithDispatchGroup:] preinitialized moduleData", nil);
    // Set up moduleData for pre-initialized module instances
    for (id<RCTBridgeModule> module in extraModules) {
        Class moduleClass = [module class];
        NSString *moduleName = RCTBridgeModuleNameForClass(moduleClass);
        
        if (RCT_DEBUG) {
            // Check for name collisions between preregistered modules
            RCTModuleData *moduleData = _moduleDataByName[moduleName];
            if (moduleData) {
                RCTLogError(@"Attempted to register RCTBridgeModule class %@ for the "
                            "name '%@', but name was already registered by class %@",
                            moduleClass, moduleName, moduleData.moduleClass);
                continue;
            }
        }
        
        if (RCTTurboModuleEnabled() && [module conformsToProtocol:@protocol(RCTTurboModule)]) {
#if RCT_DEBUG
            // TODO: don't ask for extra module for when TurboModule is enabled.
            RCTLogError(@"NativeModule '%@' was marked as TurboModule, but provided as an extra NativeModule "
                        "by the class '%@', ignoring.",
                        moduleName, moduleClass);
#endif
            continue;
        }
        
        // Instantiate moduleData container
        RCTModuleData *moduleData = [[RCTModuleData alloc] initWithModuleInstance:module bridge:self];
        _moduleDataByName[moduleName] = moduleData;
        [_moduleClassesByID addObject:moduleClass];
        [_moduleDataByID addObject:moduleData];
    }
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
}

- (id<RCTBridgeDelegate>)delegate
{
    return _parentBridge.delegate;
}

- (NSArray<RCTModuleData *> *)_initializeModules:(NSArray<id<RCTBridgeModule>> *)modules
                               withDispatchGroup:(dispatch_group_t)dispatchGroup
                                lazilyDiscovered:(BOOL)lazilyDiscovered
{
    // Set up moduleData for automatically-exported modules
    // modules中是class，是class遵守了RCTBridgeModule协议，里面都是类方法。
    // 返回的是moduleData数组
    NSArray<RCTModuleData *> *moduleDataById = [self _registerModulesForClasses:modules lazilyDiscovered:lazilyDiscovered];
    
    if (lazilyDiscovered) {
#if RCT_DEBUG
        // Lazily discovered modules do not require instantiation here,
        // as they are not allowed to have pre-instantiated instance
        // and must not require the main queue.
        for (RCTModuleData *moduleData in moduleDataById) {
            RCTAssert(!(moduleData.requiresMainQueueSetup || moduleData.hasInstance),
                      @"Module \'%@\' requires initialization on the Main Queue or has pre-instantiated, which is not supported for the lazily discovered modules.", moduleData.name);
        }
#endif
    } else {
        
        //  ---> 看这里
        
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways,
                                @"-[RCTCxxBridge initModulesWithDispatchGroup:] moduleData.hasInstance", nil);
        // Dispatch module init onto main thread for those modules that require it
        // For non-lazily discovered modules we run through the entire set of modules
        // that we have, otherwise some modules coming from the delegate
        // or module provider block, will not be properly instantiated.
        for (RCTModuleData *moduleData in _moduleDataByID) {
            if (moduleData.hasInstance && (!moduleData.requiresMainQueueSetup || RCTIsMainQueue())) {
                // Modules that were pre-initialized should ideally be set up before
                // bridge init has finished, otherwise the caller may try to access the
                // module directly rather than via `[bridge moduleForClass:]`, which won't
                // trigger the lazy initialization process. If the module cannot safely be
                // set up on the current thread, it will instead be async dispatched
                // to the main thread to be set up in _prepareModulesWithDispatchGroup:.
                (void)[moduleData instance];
            }
        }
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
        
        // From this point on, RCTDidInitializeModuleNotification notifications will
        // be sent the first time a module is accessed.
        _moduleSetupComplete = YES;
        [self _prepareModulesWithDispatchGroup:dispatchGroup];
    }
    
#if RCT_PROFILE
    if (RCTProfileIsProfiling()) {
        // Depends on moduleDataByID being loaded
        RCTProfileHookModules(self);
    }
#endif
    return moduleDataById;
}

// 调用中“lazilyDiscovered”为NO
- (NSArray<RCTModuleData *> *)_registerModulesForClasses:(NSArray<Class> *)moduleClasses
                                        lazilyDiscovered:(BOOL)lazilyDiscovered
{
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways,
                            @"-[RCTCxxBridge initModulesWithDispatchGroup:] autoexported moduleData", nil);
    
    NSArray *moduleClassesCopy = [moduleClasses copy];
    NSMutableArray<RCTModuleData *> *moduleDataByID = [NSMutableArray arrayWithCapacity:moduleClassesCopy.count];
    for (Class moduleClass in moduleClassesCopy) {
        if (RCTTurboModuleEnabled() && [moduleClass conformsToProtocol:@protocol(RCTTurboModule)]) {
            continue;
        }
        
        // 获取module的名字，是自定义的，或者是原始class名字，去掉RCT前缀之后的名字。
        NSString *moduleName = RCTBridgeModuleNameForClass(moduleClass);
        
        // Check for module name collisions
        // 检查是否有重名
        RCTModuleData *moduleData = _moduleDataByName[moduleName];
        if (moduleData) {
            if (moduleData.hasInstance || lazilyDiscovered) {
                // Existing module was preregistered, so it takes precedence
                continue;
            } else if ([moduleClass new] == nil) {
                // The new module returned nil from init, so use the old module
                continue;
            } else if ([moduleData.moduleClass new] != nil) {
                // Both modules were non-nil, so it's unclear which should take precedence
                RCTLogError(@"Attempted to register RCTBridgeModule class %@ for the "
                            "name '%@', but name was already registered by class %@",
                            moduleClass, moduleName, moduleData.moduleClass);
            }
        }
        
        // Instantiate moduleData
        // TODO #13258411: can we defer this until config generation?
#warning moduleData包含了moduleClass，以及moduleClass是否实现了XX方法的BOOL值b属性。
        moduleData = [[RCTModuleData alloc] initWithModuleClass:moduleClass bridge:self];
        
        // 将moduleData和moduleName对应保存起来
        _moduleDataByName[moduleName] = moduleData;
        
        [_moduleClassesByID addObject:moduleClass];
        [moduleDataByID addObject:moduleData];
    }
    [_moduleDataByID addObjectsFromArray:moduleDataByID];
    
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    
    return moduleDataByID;
}

@end
