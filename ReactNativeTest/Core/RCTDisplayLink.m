//
//  RCTDisplayLink.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/11.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import "RCTDisplayLink.h"

// 系统头文件
#import <QuartzCore/CADisplayLink.h>

// 项目内部头文件
#import "RCTModuleData.h"
#import "RCTFrameUpdate.h"

#define RCTAssertRunLoop() \
    RCTAssert(_runLoop == [NSRunLoop currentRunLoop], \
    @"This method must be called on the CADisplayLink run loop")

@implementation RCTDisplayLink
{
    CADisplayLink *_jsDisplayLink;
    NSMutableSet<RCTModuleData *> *_frameUpdateObservers;
    NSRunLoop *_runLoop;
}

- (instancetype)init
{
    if ((self = [super init])) {
        _frameUpdateObservers = [NSMutableSet new];
        _jsDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(_jsThreadUpdate:)];
    }
    
    return self;
}

// RCTDisplayLink被bridge持有，当bridge在invalidate的时候，会调用RCTDisplayLink的invalidate
- (void)invalidate
{
    [_jsDisplayLink invalidate];
}

// 调用的时候module是module的instance，moduleData就是moduleData
- (void)registerModuleForFrameUpdates:(id<RCTBridgeModule>)module
                       withModuleData:(RCTModuleData *)moduleData
{
    // 只有module遵守了RCTFrameUpdateObserver协议才能加进来
    // 目前来说只有RCTTiming这个module实现了RCTFrameUpdateObserver协议
    if (![moduleData.moduleClass conformsToProtocol:@protocol(RCTFrameUpdateObserver)] ||
        [_frameUpdateObservers containsObject:moduleData]) {
        return;
    }
    
    [_frameUpdateObservers addObject:moduleData];
    
    // Don't access the module instance via moduleData, as this will cause deadlock
    // module的instance就是监听者
    id<RCTFrameUpdateObserver> observer = (id<RCTFrameUpdateObserver>)module;
    __weak typeof(self) weakSelf = self;
    observer.pauseCallback = ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) {
            return;
        }
        
        CFRunLoopRef cfRunLoop = [strongSelf->_runLoop getCFRunLoop];
        if (!cfRunLoop) {
            return;
        }
        
        if ([NSRunLoop currentRunLoop] == strongSelf->_runLoop) {
            [weakSelf updateJSDisplayLinkState];
        } else {
            CFRunLoopPerformBlock(cfRunLoop, kCFRunLoopDefaultMode, ^{
                [weakSelf updateJSDisplayLinkState];
            });
            CFRunLoopWakeUp(cfRunLoop);
        }
    };
    
    // Assuming we're paused right now, we only need to update the display link's state
    // when the new observer is not paused. If it not paused, the observer will immediately
    // start receiving updates anyway.
    if (![observer isPaused] && _runLoop) {
        CFRunLoopPerformBlock([_runLoop getCFRunLoop], kCFRunLoopDefaultMode, ^{
            [self updateJSDisplayLinkState];
        });
    }
}

- (void)_jsThreadUpdate:(CADisplayLink *)displayLink
{
    // 必须在CADisplayLink所在的runLoop上才能执行
    RCTAssertRunLoop();
    
    RCT_PROFILE_BEGIN_EVENT(RCTProfileTagAlways, @"-[RCTDisplayLink _jsThreadUpdate:]", nil);
    
    RCTFrameUpdate *frameUpdate = [[RCTFrameUpdate alloc] initWithDisplayLink:displayLink];
    for (RCTModuleData *moduleData in _frameUpdateObservers) {
        id<RCTFrameUpdateObserver> observer = (id<RCTFrameUpdateObserver>)moduleData.instance;
        if (!observer.paused) {
            RCTProfileBeginFlowEvent();
            
            [self dispatchBlock:^{
                RCTProfileEndFlowEvent();
                [observer didUpdateFrame:frameUpdate];
            } queue:moduleData.methodQueue];
        }
    }
    
    [self updateJSDisplayLinkState];
    
    RCTProfileImmediateEvent(RCTProfileTagAlways, @"JS Thread Tick", displayLink.timestamp, 'g');
    
    RCT_PROFILE_END_EVENT(RCTProfileTagAlways, @"objc_call");
}

- (void)dispatchBlock:(dispatch_block_t)block
                queue:(dispatch_queue_t)queue
{
    if (queue == RCTJSThread) {
        block();
    } else if (queue) {
        dispatch_async(queue, block);
    }
}

- (void)updateJSDisplayLinkState
{
    RCTAssertRunLoop();
    
    BOOL pauseDisplayLink = YES;
    for (RCTModuleData *moduleData in _frameUpdateObservers) {
        id<RCTFrameUpdateObserver> observer = (id<RCTFrameUpdateObserver>)moduleData.instance;
        if (!observer.paused) {
            pauseDisplayLink = NO;
            break;
        }
    }
    
    _jsDisplayLink.paused = pauseDisplayLink;
}

@end
