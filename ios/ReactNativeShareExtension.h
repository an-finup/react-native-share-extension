#import <UIKit/UIKit.h>
#import "React/RCTBridgeModule.h"

@interface ReactNativeShareExtension : UIViewController<RCTBridgeModule>

- (UIView*) shareView;

- (UIView*) shareViewWithRCTBridge:(RCTBridge*)sharedBridge;

@end
