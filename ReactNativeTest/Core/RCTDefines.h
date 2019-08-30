//
//  RCTDefines.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/27.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#ifndef RCTDefines_h
#define RCTDefines_h

/**
 * Make global functions usable in C++
 */
#if defined(__cplusplus)
#define RCT_EXTERN extern "C" __attribute__((visibility("default")))
#define RCT_EXTERN_C_BEGIN extern "C" {
#define RCT_EXTERN_C_END }
#else
#define RCT_EXTERN extern __attribute__((visibility("default")))
#define RCT_EXTERN_C_BEGIN
#define RCT_EXTERN_C_END
#endif

#endif /* RCTDefines_h */
