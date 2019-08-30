//
//  RCTBridgeDelegate.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/28.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@protocol RCTBridgeDelegate <NSObject>

// 提供js代码URL
- (NSURL *)sourceURLForBridge:(RCTBridge *)bridge;



@optional



@end

NS_ASSUME_NONNULL_END
