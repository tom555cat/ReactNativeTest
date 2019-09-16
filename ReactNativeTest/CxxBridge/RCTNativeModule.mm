//
//  RCTNativeModule.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/16.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "RCTNativeModule.h"
#include "RCTModuleData.h"

#import "RCTBridge.h"

namespace facebook {
namespace react {
    
RCTNativeModule::RCTNativeModule(RCTBridge *bridge, RCTModuleData *moduleData)
    : m_bridge(bridge)
    , m_moduleData(moduleData) {}
    
}
}
