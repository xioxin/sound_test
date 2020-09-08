#import "LabSoundPlugin.h"
#if __has_include(<lab_sound/lab_sound-Swift.h>)
#import <lab_sound/lab_sound-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "lab_sound-Swift.h"
#endif

@implementation LabSoundPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftLabSoundPlugin registerWithRegistrar:registrar];
}
@end
