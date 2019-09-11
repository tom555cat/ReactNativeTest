//
//  RCTFrameUpdate.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/11.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

@class CADisplayLink;

NS_ASSUME_NONNULL_BEGIN

@interface RCTFrameUpdate : NSObject

// 来自displayLink的timestamp属性，是上一帧展示的时间
@property (nonatomic, readonly) NSTimeInterval timestamp;

/**
 * Time since the last frame update ( >= 16.6ms )
 */
// 来自displayLink的duration属性，是大概的屏幕刷新时间间隔
@property (nonatomic, readonly) NSTimeInterval deltaTime;

- (instancetype)initWithDisplayLink:(CADisplayLink *)displayLink NS_DESIGNATED_INITIALIZER;

@end

@protocol RCTFrameUpdateObserver <NSObject>

// 都是必须实现的

// 当屏幕刷新的时候调用(if paused != YES)
- (void)didUpdateFrame:(RCTFrameUpdate *)update;

// synthesize并且设置为true，去暂停-didUpdateFrame:方法的调用
@property (nonatomic, readonly, getter=isPaused) BOOL paused;

// 一个回调，observer应该当paused改变的时候调用；observer就是module的instance
@property (nonatomic, copy) dispatch_block_t pauseCallback;

@end

NS_ASSUME_NONNULL_END
