//
//  RCTUtils.m
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/29.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

RCT_EXTERN NSString *RCTDropReactPrefixes(NSString *s)
{
    if ([s hasPrefix:@"RK"]) {
        return [s substringFromIndex:2];
    } else if ([s hasPrefix:@"RCT"]) {
        return [s substringFromIndex:3];
    }
    
    return s;
}
