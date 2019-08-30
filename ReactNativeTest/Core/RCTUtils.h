//
//  RCTUtils.h
//  ReactNativeTest
//
//  Created by tongleiming on 2019/8/29.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#ifndef RCTUtils_h
#define RCTUtils_h

#include "RCTDefines.h"
#include <Foundation/Foundation.h>

// Given a string, drop common RN prefixes (RCT, RK, etc.)
RCT_EXTERN NSString *RCTDropReactPrefixes(NSString *s);

#endif /* RCTUtils_h */
