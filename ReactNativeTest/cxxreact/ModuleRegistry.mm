//
//  ModuleRegistry.cpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/16.
//  Copyright © 2019 tongleiming. All rights reserved.
//

#include "ModuleRegistry.h"
#include "NativeModule.h"

namespace facebook {
namespace react {
    
namespace {

ModuleRegistry::ModuleRegistry(std::vector<std::unique_ptr<NativeModule>> modules, ModuleNotFoundCallback callback)
    : modules_{std::move(modules)}, moduleNotFoundCallback_{callback} {}
    
}
}
}
