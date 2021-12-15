#import <UIKit/UIKit.h>
#import "React/RCTBridgeModule.h"

@interface ReactNativeShareExtension : UIViewController<RCTBridgeModule>
- (UIView*) shareViewWithRCTBridge:(RCTBridge*)sharedBridge;
@end
