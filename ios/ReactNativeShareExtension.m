#import "ReactNativeShareExtension.h"
#import "React/RCTRootView.h"
#import "React/RCTBundleURLProvider.h"
#import <MobileCoreServices/MobileCoreServices.h>

#define URL_IDENTIFIER @"public.url"
#define IMAGE_IDENTIFIER @"public.image"
#define TEXT_IDENTIFIER (NSString *)kUTTypePlainText

NSExtensionContext* extensionContext;

RCTBridge *sharedBridge;
NSURL *jsCodeLocation;

@implementation ReactNativeShareExtension {
    NSTimer *autoTimer;
    NSString* type;
    NSString* value;
}

- (UIView*) shareView {
    return nil;
}

- (UIView*) shareViewWithRCTBridge:(RCTBridge*)sharedBridge {
    return nil;
}

RCT_EXPORT_MODULE();

- (dispatch_queue_t)methodQueue
{
  return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
  return YES;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    //object variable for extension doesn't work for react-native. It must be assign to global
    //variable extensionContext. in this way, both exported method can touch extensionContext
    extensionContext = self.extensionContext;

    if (sharedBridge == nil) {

        jsCodeLocation = [[RCTBundleURLProvider sharedSettings] jsBundleURLForBundleRoot:@"index" fallbackResource:nil];
        sharedBridge = [[RCTBridge alloc] initWithBundleURL:jsCodeLocation
                                             moduleProvider:nil
                                              launchOptions:nil];
    }

    UIView *rootView = [self shareViewWithRCTBridge:sharedBridge];

    if (rootView == nil) {
        // Fallback to the previous version if shareViewWithRCTBridge isn't implemented.
        rootView = [self shareView];
    }
    if (rootView.backgroundColor == nil) {
        rootView.backgroundColor = [[UIColor alloc] initWithRed:1 green:1 blue:1 alpha:0.1];
    }

    self.view = rootView;
}


RCT_EXPORT_METHOD(close) {
    [extensionContext completeRequestReturningItems:nil
                                  completionHandler:nil];
    // Set the view to nil so it gets cleaned up.
    self.view = nil;

    [sharedBridge invalidate];
    sharedBridge = nil;
    exit(0);
}



RCT_EXPORT_METHOD(openURL:(NSString *)url) {
  // UIApplication *application = [UIApplication sharedApplication];
  // NSURL *urlToOpen = [NSURL URLWithString:[url stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
  // [application openURL:urlToOpen options:@{} completionHandler: nil];
  NSFileManager *fileManager = NSFileManager.defaultManager;
  NSURL *applicationDocumentsDirectory = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
  NSURL *updatesDirectory = [applicationDocumentsDirectory URLByAppendingPathComponent:@".expo-internal"];

  static NSString * const EXUpdatesDatabaseLatestFilename = @"expo-v6.db";
  //sqlite3 *db;
  NSURL *dbUrl = [updatesDirectory URLByAppendingPathComponent:EXUpdatesDatabaseLatestFilename];

  NSLog(@"HELLO HELLO HELLO: %s", [[dbUrl path] UTF8String]);
  //int resultCode = sqlite3_open([[dbUrl path] UTF8String], &db);
}



RCT_REMAP_METHOD(data,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject)
{
    [self extractDataFromContext: extensionContext withCallback:^(NSString* val, NSString* contentType, NSException* err) {
        if(err) {
            reject(@"error", err.description, nil);
        } else {
            resolve(@{
                      @"type": contentType,
                      @"value": val
                      });
        }
    }];
}

- (void)extractDataFromContext:(NSExtensionContext *)context withCallback:(void(^)(NSString *value, NSString* contentType, NSException *exception))callback {
    @try {
        NSExtensionItem *item = [context.inputItems firstObject];
        NSArray *attachments = item.attachments;

        __block NSItemProvider *urlProvider = nil;
        __block NSItemProvider *imageProvider = nil;
        __block NSItemProvider *textProvider = nil;

        [attachments enumerateObjectsUsingBlock:^(NSItemProvider *provider, NSUInteger idx, BOOL *stop) {
            if([provider hasItemConformingToTypeIdentifier:URL_IDENTIFIER]) {
                urlProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:TEXT_IDENTIFIER]){
                textProvider = provider;
                *stop = YES;
            } else if ([provider hasItemConformingToTypeIdentifier:IMAGE_IDENTIFIER]){
                imageProvider = provider;
                *stop = YES;
            }
        }];

        if(urlProvider) {
            [urlProvider loadItemForTypeIdentifier:URL_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSURL *url = (NSURL *)item;

                if(callback) {
                    callback([url absoluteString], @"text/plain", nil);
                }
            }];
        } else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {

                if ([(NSObject *)item isKindOfClass:[UIImage class]]){

                    UIImage *sharedImage;
                    sharedImage = (UIImage *)item;
                    NSData *imageData = UIImagePNGRepresentation(sharedImage);
                    NSString *base64String = [imageData base64EncodedStringWithOptions:0];
                    if(callback) {
                        callback(base64String, @"base64/art", nil);
                    }

                } else if ([(NSObject *)item isKindOfClass:[NSURL class]]){
                    NSURL* url = (NSURL *)item;
                    if(callback) {
                        callback([url absoluteString], [[[url absoluteString] pathExtension] lowercaseString], nil);
                    }
                } else {
                    if(callback) {
                        callback(nil, nil, nil);
                    }
                }

            }];
        } else if (imageProvider) {
            [imageProvider loadItemForTypeIdentifier:IMAGE_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {

                /**
                 * Save the image to NSTemporaryDirectory(), which cleans itself tri-daily.
                 * This is necessary as the iOS 11 screenshot editor gives us a UIImage, while
                 * sharing from Photos and similar apps gives us a URL
                 * Therefore the solution is to save a UIImage, either way, and return the local path to that temp UIImage
                 * This path will be sent to React Native and can be processed and accessed RN side.
                **/

                UIImage *sharedImage;
                NSString *filePath = nil;
                NSString *fullPath = nil;

                if ([(NSObject *)item isKindOfClass:[UIImage class]]){
                    sharedImage = (UIImage *)item;
                    fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"screenshot.png"];
                }else if ([(NSObject *)item isKindOfClass:[NSURL class]]){
                    NSURL* url = (NSURL *)item;
                    fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:url.lastPathComponent];
                    NSData *data = [NSData dataWithContentsOfURL:url];
                    sharedImage = [UIImage imageWithData:data];
                }

                NSString *fullPathFF = [NSString stringWithFormat:@"file://%@", fullPath];
                [UIImagePNGRepresentation(sharedImage) writeToFile:fullPathFF atomically:YES];

                if(callback) {
                    callback(fullPathFF, [fullPath pathExtension], nil);
                }
            }];
        } else if (textProvider) {
            [textProvider loadItemForTypeIdentifier:TEXT_IDENTIFIER options:nil completionHandler:^(id<NSSecureCoding> item, NSError *error) {
                NSString *text = (NSString *)item;

                if(callback) {
                    callback(text, @"text/plain", nil);
                }
            }];
        } else {
            if(callback) {
                callback(nil, nil, [NSException exceptionWithName:@"Error" reason:@"couldn't find provider" userInfo:nil]);
            }
        }
    }
    @catch (NSException *exception) {
        if(callback) {
            callback(nil, nil, exception);
        }
    }
}

@end
