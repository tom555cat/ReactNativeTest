//
//  RCTNativeModule.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/16.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "NativeModule.h"

namespace facebook {
namespace react {
    
class RCTNativeModule : public NativeModule {
public:
    RCTNativeModule(RCTBridge *bridge, RCTModuleData *moduleData);
    
private:
    __weak RCTBridge *m_bridge;
    RCTModuleData *m_moduleData;
};
    
}
}
