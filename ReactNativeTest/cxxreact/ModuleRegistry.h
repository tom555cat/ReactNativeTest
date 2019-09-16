//
//  ModuleRegistry.hpp
//  ReactNativeTest
//
//  Created by tongleiming on 2019/9/16.
//  Copyright © 2019 tongleiming. All rights reserved.
//


namespace facebook {
namespace react {
    
class RN_EXPORT ModuleRegistry {
public:
    ModuleRegistry(std::vector<std::unique_ptr<NativeModule>> modules, ModuleNotFoundCallback callback = nullptr);
    
private:
    // This is always populated
    // 保存了nativeModule的数组
    std::vector<std::unique_ptr<NativeModule>> modules_;
    
    // module没有被找到的回调
    ModuleNotFoundCallback moduleNotFoundCallback_;
};
    
}}
