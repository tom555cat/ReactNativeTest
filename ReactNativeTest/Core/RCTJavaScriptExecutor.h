//
//  RCTJavaScriptExecutor.h
//  ReactNativeTest
//
//  Created by tom555cat on 2019/9/14.
//  Copyright © 2019年 tongleiming. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^RCTJavaScriptCompleteBlock)(NSError *error);
typedef void (^RCTJavaScriptCallback)(id result, NSError *error);

@protocol RCTJavaScriptExecutor <NSObject>

@end
