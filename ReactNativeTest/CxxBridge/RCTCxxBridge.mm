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

#include "JSCExecutorFactory.h"
#include "RCTCxxUtils.h"
#include "RCTMessageThread.h"
#include "Instance.h"

using namespace facebook::jsi;
using namespace facebook::react;

@interface RCTCxxBridge ()

// 居然还弱引用了父类
@property (nonatomic, weak, readonly) RCTBridge *parentBridge;
// 所有的moduleData中的instance创建完之后才会设置为YES。
@property (nonatomic, assign, readonly) BOOL moduleSetupComplete;

@end

#warning struct在C++中的继承
#warning 在struct中使用__weak
#warning struct中覆盖父类方法
struct RCTInstanceCallback : public InstanceCallback {
    __weak RCTCxxBridge *bridge_;
    RCTInstanceCallback(RCTCxxBridge *bridge): bridge_(bridge) {};
    void onBatchComplete() override {
        // There's no interface to call this per partial batch
        [bridge_ partialBatchDidFlush];
        [bridge_ batchDidComplete];
    }
};

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
    
    // 这个C++线程类持有了_jsThread的runLoop
    std::shared_ptr<RCTMessageThread> _jsMessageThread;
#warning 这个锁保护了哪些资源的竞争?
    std::mutex _moduleRegistryLock;
    
    // This is uniquely owned, but weak_ptr is used.
    std::shared_ptr<Instance> _reactInstance;
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

#warning JSThread单独启动了一个线程，而且使用了线程保活的方式，可以与笔记中的线程保活方式进行对比
+ (void)runRunLoop
{
    @autoreleasepool {
        RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"-[RCTCxxBridge runJSRunLoop] setup", nil);
        
        // copy thread name to pthread name
        pthread_setname_np([NSThread currentThread].name.UTF8String);
        
        // Set up a dummy runloop source to avoid spinning
        CFRunLoopSourceContext noSpinCtx = {0, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL};
        CFRunLoopSourceRef noSpinSource = CFRunLoopSourceCreate(NULL, 0, &noSpinCtx);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), noSpinSource, kCFRunLoopDefaultMode);
        CFRelease(noSpinSource);
        
        RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
        
        // run the run loop
        while (kCFRunLoopRunStopped != CFRunLoopRunInMode(kCFRunLoopDefaultMode, ((NSDate *)[NSDate distantFuture]).timeIntervalSinceReferenceDate, NO)) {
            RCTAssert(NO, @"not reached assertion"); // runloop spun. that's bad.
        }
    }
}

// 在js线程上执行任务
- (void)ensureOnJavaScriptThread:(dispatch_block_t)block
{
    RCTAssert(_jsThread, @"This method must not be called before the JS thread is created");
    
    // This does not use _jsMessageThread because it may be called early before the runloop reference is captured
    // and _jsMessageThread is valid. _jsMessageThread also doesn't allow us to shortcut the dispatch if we're
    // already on the correct thread.
    
    if ([NSThread currentThread] == _jsThread) {
        [self _tryAndHandleError:block];
    } else {
        [self performSelector:@selector(_tryAndHandleError:)
                     onThread:_jsThread
                   withObject:block
                waitUntilDone:NO];
    }
}

- (void)_tryAndHandleError:(dispatch_block_t)block
{
    NSError *error = tryAndReturnError(block);
    if (error) {
        [self handleError:error];
    }
}

#warning 错误处理以后再看
- (void)handleError:(NSError *)error
{
    // This is generally called when the infrastructure throws an
    // exception while calling JS.  Most product exceptions will not go
    // through this method, but through RCTExceptionManager.
    
    // There are three possible states:
    // 1. initializing == _valid && _loading
    // 2. initializing/loading finished (success or failure) == _valid && !_loading
    // 3. invalidated == !_valid && !_loading
    
    // !_valid && _loading can't happen.
    
    // In state 1: on main queue, move to state 2, reset the bridge, and RCTFatal.
    // In state 2: go directly to RCTFatal.  Do not enqueue, do not collect $200.
    // In state 3: do nothing.
    
    if (self->_valid && !self->_loading) {
        if ([error userInfo][RCTJSRawStackTraceKey]) {
            [self.redBox showErrorMessage:[error localizedDescription]
                             withRawStack:[error userInfo][RCTJSRawStackTraceKey]];
        }
        
        RCTFatal(error);
        
        // RN will stop, but let the rest of the app keep going.
        return;
    }
    
    if (!_valid || !_loading) {
        return;
    }
    
    // Hack: once the bridge is invalidated below, it won't initialize any new native
    // modules. Initialize the redbox module now so we can still report this error.
    RCTRedBox *redBox = [self redBox];
    
    _loading = NO;
    _valid = NO;
    _moduleRegistryCreated = NO;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_jsMessageThread) {
            // Make sure initializeBridge completed
            self->_jsMessageThread->runOnQueueSync([] {});
        }
        
        self->_reactInstance.reset();
        self->_jsMessageThread.reset();
        
        [[NSNotificationCenter defaultCenter]
         postNotificationName:RCTJavaScriptDidFailToLoadNotification
         object:self->_parentBridge userInfo:@{@"bridge": self, @"error": error}];
        
        if ([error userInfo][RCTJSRawStackTraceKey]) {
            [redBox showErrorMessage:[error localizedDescription]
                        withRawStack:[error userInfo][RCTJSRawStackTraceKey]];
        }
        
        RCTFatal(error);
    });
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
    // 意味着有些native modules可以懒加载，
    (void)[self _initializeModules:RCTGetModuleClasses() withDispatchGroup:prepareBridge lazilyDiscovered:NO];
    
    // 只有在debug状态才会执行
    [self registerExtraLazyModules];
    
    [_performanceLogger markStopForTag:RCTPLNativeModuleInit];
    
    // This doesn't really do anything.  The real work happens in initializeBridge.
#warning 因为是一个实例变量，还传递了一个new Instance，所以暂时理解为_reactInstance使用了一个新创建的Instance来进行了实例化。
    _reactInstance.reset(new Instance);
    
    __weak RCTCxxBridge *weakSelf = self;
    
    // Prepare executor factory (shared_ptr for copy into block)
#warning executorFactory是一个只能指针
    // 空只能指针，指向类型为JSExecutorFactory的对象。
    std::shared_ptr<JSExecutorFactory> executorFactory;
#warning 在start的时候executorClass是空，走的是上边
    if (!self.executorClass) {
#warning 项目里没设置self.delegate
        if ([self.delegate conformsToProtocol:@protocol(RCTCxxBridgeDelegate)]) {
            id<RCTCxxBridgeDelegate> cxxDelegate = (id<RCTCxxBridgeDelegate>) self.delegate;
            executorFactory = [cxxDelegate jsExecutorFactoryForBridge:self];
        }
        if (!executorFactory) {
            // ----> 直接在这里
            // 最安全的分配和使用动态内存的方法是调用make_shared库函数，此函数在动态内存中分配一个对象并初始化它，
            // 返回指向此对象的shared_ptr。创建时make_shared使用给定的参数来构造给定类型的对象。
            // 这里就是使用空指针nullptr创建了一个JSCExecutorFactory
            // 这里只是一个使用默认的初始化函数，参数还是个nullptr，相当于什么都没做
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

// 当前方法是在RCTCxxBridge的"NSThread *_jsThread"上执行的；
// 所以在内部创建_jsMessageThread的时候，使用的第一个参数是_jsThread的runLoop。
- (void)_initializeBridge:(std::shared_ptr<JSExecutorFactory>)executorFactory
{
    if (!self.valid) {
        return;
    }
    
    RCTAssertJSThread();
    __weak RCTCxxBridge *weakSelf = self;
    // _jsMessageThread在初始化时内部保存了jsThread的runLoop，和一个错误回调Block
    _jsMessageThread = std::make_shared<RCTMessageThread>([NSRunLoop currentRunLoop], ^(NSError *error) {
        if (error) {
            [weakSelf handleError:error];
        }
    });
    
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"-[RCTCxxBridge initializeBridge:]", nil);
    // This can only be false if the bridge was invalidated before startup completed
#warning 在start中通过new Instance创建了一个。
    if (_reactInstance) {
#if RCT_DEV
        executorFactory = std::make_shared<GetDescAdapter>(self, executorFactory);
#endif
        
        [self _initializeBridgeLocked:executorFactory];
        
#if RCT_PROFILE
        if (RCTProfileIsProfiling()) {
            _reactInstance->setGlobalVariable(
                                              "__RCTProfileIsProfiling",
                                              std::make_unique<JSBigStdString>("true"));
        }
#endif
    }
    
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
}

- (std::shared_ptr<ModuleRegistry>)_buildModuleRegistryUnlocked
{
    if (!self.valid) {
        return {};
    }
    
    [_performanceLogger markStartForTag:RCTPLNativeModulePrepareConfig];
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"-[RCTCxxBridge buildModuleRegistry]", nil);
    
    __weak __typeof(self) weakSelf = self;
    ModuleRegistry::ModuleNotFoundCallback moduleNotFoundCallback = ^bool(const std::string &name) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        return [strongSelf.delegate respondsToSelector:@selector(bridge:didNotFindModule:)] &&
        [strongSelf.delegate bridge:strongSelf didNotFindModule:@(name.c_str())];
    };
    
    // createNativeModules(_moduleDataByID, self, _reactInstance),
    // _moduleDataByID就是moduleData的数组
    auto registry = std::make_shared<ModuleRegistry>(
                                                     createNativeModules(_moduleDataByID, self, _reactInstance),
                                                     moduleNotFoundCallback);
    
    [_performanceLogger markStopForTag:RCTPLNativeModulePrepareConfig];
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
    
    return registry;
}

- (void)_initializeBridgeLocked:(std::shared_ptr<JSExecutorFactory>)executorFactory
{
    std::lock_guard<std::mutex> guard(_moduleRegistryLock);
    
    // This is async, but any calls into JS are blocked by the m_syncReady CV in Instance
    // [self _buildModuleRegistryUnlocked]返回的就是module的注册结果，被称为moduleRegistry
    // 如果有很多回调，一个一个地传递搞得参数会很多，所以直接搞了一个回调结构体
    
    // 这个executorFactory
    _reactInstance->initializeBridge(
                                     std::make_unique<RCTInstanceCallback>(self),
                                     executorFactory,
                                     _jsMessageThread,
                                     [self _buildModuleRegistryUnlocked]);
    _moduleRegistryCreated = YES;
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

- (void)registerExtraLazyModules
{
#if RCT_DEBUG
    // This is debug-only and only when Chrome is attached, since it expects all modules to be already
    // available on start up. Otherwise, we can let the lazy module discovery to load them on demand.
    Class executorClass = [_parentBridge executorClass];
    if (executorClass && [NSStringFromClass(executorClass) isEqualToString:@"RCTWebSocketExecutor"]) {
        NSDictionary<NSString *, Class> *moduleClasses = nil;
        if ([self.delegate respondsToSelector:@selector(extraLazyModuleClassesForBridge:)]) {
            moduleClasses = [self.delegate extraLazyModuleClassesForBridge:_parentBridge];
        }
        
        if (!moduleClasses) {
            return;
        }
        
        // This logic is mostly copied from `registerModulesForClasses:`, but with one difference:
        // we must use the names provided by the delegate method here.
        for (NSString *moduleName in moduleClasses) {
            Class moduleClass = moduleClasses[moduleName];
            if (RCTTurboModuleEnabled() && [moduleClass conformsToProtocol:@protocol(RCTTurboModule)]) {
                continue;
            }
            
            // Check for module name collisions
            RCTModuleData *moduleData = _moduleDataByName[moduleName];
            if (moduleData) {
                if (moduleData.hasInstance) {
                    // Existing module was preregistered, so it takes precedence
                    continue;
                } else if ([moduleClass new] == nil) {
                    // The new module returned nil from init, so use the old module
                    continue;
                } else if ([moduleData.moduleClass new] != nil) {
                    // Use existing module since it was already loaded but not yet instantiated.
                    continue;
                }
            }
            
            moduleData = [[RCTModuleData alloc] initWithModuleClass:moduleClass bridge:self];
            
            _moduleDataByName[moduleName] = moduleData;
            [_moduleClassesByID addObject:moduleClass];
            [_moduleDataByID addObject:moduleData];
        }
    }
#endif
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
#warning 这个阶段的moduleData创建module实例的判断条件比较奇怪
#warning moduleData有module的instance了，并且(不需要在主队列上初始化，或者当前是主队列)
#warning 打断点查看for循环里的的[moduleData instance]没有执行
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
        // 主要是需要在主队列上实例化的module，会在这个函数中进行实例化
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

// 主要是需要在主队列上实例化的module，会在这个函数中进行实例化
- (void)_prepareModulesWithDispatchGroup:(dispatch_group_t)dispatchGroup
{
    RCT_PROFILE_BEGIN_EVENT(0, @"-[RCTCxxBridge _prepareModulesWithDispatchGroup]", nil);
    
    BOOL initializeImmediately = NO;
    if (dispatchGroup == NULL) {
        // If no dispatchGroup is passed in, we must prepare everything immediately.
        // We better be on the right thread too.
        RCTAssertMainQueue();
        initializeImmediately = YES;
    }
    
    // Set up modules that require main thread init or constants export
    [_performanceLogger setValue:0 forTag:RCTPLNativeModuleMainThread];
    
    // 主要是需要从主队列创建module instance进行创建instance
    for (RCTModuleData *moduleData in _moduleDataByID) {
        if (moduleData.requiresMainQueueSetup) {
            // Modules that need to be set up on the main thread cannot be initialized
            // lazily when required without doing a dispatch_sync to the main thread,
            // which can result in deadlock. To avoid this, we initialize all of these
            // modules on the main thread in parallel with loading the JS code, so
            // they will already be available before they are ever required.
            dispatch_block_t block = ^{
                if (self.valid && ![moduleData.moduleClass isSubclassOfClass:[RCTCxxModule class]]) {
                    [self->_performanceLogger appendStartForTag:RCTPLNativeModuleMainThread];
                    (void)[moduleData instance];
                    [moduleData gatherConstants];
                    [self->_performanceLogger appendStopForTag:RCTPLNativeModuleMainThread];
                }
            };
            
            if (initializeImmediately && RCTIsMainQueue()) {
                block();
            } else {
                // We've already checked that dispatchGroup is non-null, but this satisifies the
                // Xcode analyzer
                if (dispatchGroup) {
                    dispatch_group_async(dispatchGroup, dispatch_get_main_queue(), block);
                }
            }
            _modulesInitializedOnMainQueue++;
        }
    }
    [_performanceLogger setValue:_modulesInitializedOnMainQueue forTag:RCTPLNativeModuleMainThreadUsesCount];
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
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

- (void)registerModuleForFrameUpdates:(id<RCTBridgeModule>)module
                       withModuleData:(RCTModuleData *)moduleData {
    [_displayLink registerModuleForFrameUpdates:module withModuleData:moduleData];
}

#pragma mark - RCTBridge methods


// 能从任何线程调用
- (void)enqueueJSCall:(NSString *)module method:(NSString *)method args:(NSArray *)args completion:(dispatch_block_t)completion {
    if (!self.valid) {
        return;
    }

#warning 查看这个宏怎么写
    RCTProfileBeginFlowEvent();
    __weak __typeof(self) weakSelf = self;
    [self _runAfterLoad:^(){
        RCTProfileEndFlowEvent();
        
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        if (strongSelf->_reactInstance) {
            strongSelf->_reactInstance->call
        }
        
    }];
}


@end
