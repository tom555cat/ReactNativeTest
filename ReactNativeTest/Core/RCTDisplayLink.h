//
//  RCTDisplayLink.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/11.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol RCTBridgeModule;
@class RCTModuleData;

NS_ASSUME_NONNULL_BEGIN

@interface RCTDisplayLink : NSObject

- (instancetype)init;

- (void)registerModuleForFrameUpdates:(id<RCTBridgeModule>)module
                       withModuleData:(RCTModuleData *)moduleData;

@end

NS_ASSUME_NONNULL_END
