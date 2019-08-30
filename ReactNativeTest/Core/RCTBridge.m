//
//  RCTBridge.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/27.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTBridge.h"
#import "RCTBridge+Private.h"

NSString *const RCTJavaScriptWillStartLoadingNotification = @"RCTJavaScriptWillStartLoadingNotification";

// 保证只有RCTBridge内部才可以使用
static NSMutableArray<Class> *RCTModuleClasses;
static dispatch_queue_t RCTModuleClassesSyncQueue;

// 读取RCTModuleClasses中的所有class
NSArray<Class> *RCTGetModuleClasses(void)
{
    __block NSArray<Class> *result;
    dispatch_sync(RCTModuleClassesSyncQueue, ^{
        result = [RCTModuleClasses copy];
    });
    return result;
}

// All modules must be registered prior to the first bridge initialization.
// 所有的module都必须在bridge初始化之前进行注册，所以每一个module都是在+load方法中调用的这个方法
void RCTRegisterModule(Class);
void RCTRegisterModule(Class moduleClass)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        RCTModuleClasses = [NSMutableArray new];
        RCTModuleClassesSyncQueue = dispatch_queue_create("com.facebook.react.ModuleClassesSyncQueue", DISPATCH_QUEUE_CONCURRENT);
    });
    
    RCTAssert([moduleClass conformsToProtocol:@protocol(RCTBridgeModule)],
              @"%@ does not conform to the RCTBridgeModule protocol",
              moduleClass);
    
    // Register module
    dispatch_barrier_async(RCTModuleClassesSyncQueue, ^{
        [RCTModuleClasses addObject:moduleClass];
    });
}

/**
 * This function returns the module name for a given class.
 */
// 读取module的+moduleName方法，返回moduleName，如果没有，则使用class名代替;
// 如果名字之前有RCT，则删除前面的3个字母。
NSString *RCTBridgeModuleNameForClass(Class cls)
{
#if RCT_DEBUG
    RCTAssert([cls conformsToProtocol:@protocol(RCTBridgeModule)],
              @"Bridge module `%@` does not conform to RCTBridgeModule", cls);
#endif
    
    NSString *name = [cls moduleName];
    if (name.length == 0) {
        name = NSStringFromClass(cls);
    }
    
    return RCTDropReactPrefixes(name);
}


@implementation RCTBridge
{
    // 一个记录标记，需要用户实现sourceURLForBridge代理方法来提供
    NSURL *_delegateBundleURL;
}

///-----------------------------------------
/// @name 静态RCTCurrentBridgeInstance
///-----------------------------------------

#warning 这是一个静态属性，肯定不适合多线程读写，好像只是为log提供的一个类接口
static RCTBridge *RCTCurrentBridgeInstance = nil;

+ (instancetype)currentBridge
{
    return RCTCurrentBridgeInstance;
}

+ (void)setCurrentBridge:(RCTBridge *)currentBridge
{
    RCTCurrentBridgeInstance = currentBridge;
}

///-----------------------------------------
/// @name 初始化
///-----------------------------------------
- (instancetype)initWithBundleURL:(NSURL *)bundleURL
                   moduleProvider:(RCTBridgeModuleListProvider)block
                    launchOptions:(NSDictionary *)launchOptions
{
    return [self initWithDelegate:nil
                        bundleURL:bundleURL
                   moduleProvider:block
                    launchOptions:launchOptions];
}

- (instancetype)initWithDelegate:(id<RCTBridgeDelegate>)delegate
                       bundleURL:(NSURL *)bundleURL
                  moduleProvider:(RCTBridgeModuleListProvider)block
                   launchOptions:(NSDictionary *)launchOptions
{
    if (self = [super init]) {
#warning _delegate对应的属性是只读属性，但是通过实例变量进行写入
        _delegate = delegate;
        _bundleURL = bundleURL;
        _moduleProvider = block;
        _launchOptions = [launchOptions copy];
        
        [self setUp];
    }
    return self;
}

- (Class)bridgeClass
{
    return [RCTCxxBridge class];
}

- (void)setUp
{
    RCT_PROFILE_BEGIN_EVENT(0, @"-[RCTBridge setUp]", nil);
    
    _performanceLogger = [RCTPerformanceLogger new];
    [_performanceLogger markStartForTag:RCTPLBridgeStartup];
    [_performanceLogger markStartForTag:RCTPLTTI];
    
    Class bridgeClass = self.bridgeClass;
    
#if RCT_DEV
    RCTExecuteOnMainQueue(^{
        RCTRegisterReloadCommandListener(self);
    });
#endif
    
    // Only update bundleURL from delegate if delegate bundleURL has changed
    NSURL *previousDelegateURL = _delegateBundleURL;
    _delegateBundleURL = [self.delegate sourceURLForBridge:self];
    if (_delegateBundleURL && ![_delegateBundleURL isEqual:previousDelegateURL]) {
        _bundleURL = _delegateBundleURL;
    }
    
    // Sanitize the bundle URL
#warning RCTConvert应该是一个工具类
    _bundleURL = [RCTConvert NSURL:_bundleURL.absoluteString];
    
    self.batchedBridge = [[bridgeClass alloc] initWithParentBridge:self];
    [self.batchedBridge start];
    
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"");
}


@end
