//
//  RCTFrameUpdate.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/11.
//  Copyright © 2019 tongleiming. All rights reserved.
//
#import <QuartzCore/CADisplayLink.h>

#import "RCTFrameUpdate.h"

@implementation RCTFrameUpdate

- (instancetype)initWithDisplayLink:(CADisplayLink *)displayLink
{
    if ((self = [super init])) {
        _timestamp = displayLink.timestamp;
        _deltaTime = displayLink.duration;
    }
    return self;
}

@end
