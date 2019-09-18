//
//  JSCRuntime.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/17.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#pragma once

#include <memory.h>
#include "jsi.h"


namespace facebook {
namespace jsc {
    
std::unique_ptr<jsi::Runtime> makeJSCRuntime();
    
} // namespace jsc
} // namespace facebook
