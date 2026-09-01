#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import "ActionGestureHeaders.h"

NS_ASSUME_NONNULL_BEGIN
FOUNDATION_EXPORT NSString *const AGGestureSingle;
FOUNDATION_EXPORT NSString *const AGGestureDouble;
FOUNDATION_EXPORT NSString *const AGGestureLong;
FOUNDATION_EXPORT NSString *const AGShortcutOff;
FOUNDATION_EXPORT NSString *const AGShortcutWeChatScan;
FOUNDATION_EXPORT NSString *const AGShortcutWeChatPay;
FOUNDATION_EXPORT NSString *const AGShortcutAlipayScan;
FOUNDATION_EXPORT NSString *const AGShortcutAlipayPay;

@interface ActionGestureHelper : NSObject
@property (nonatomic, copy) NSString *currentGesture;
@property (nonatomic, readonly) NSBundle *settingsBundle;
+ (instancetype)sharedHelper;
- (void)loadEditorState;
- (BOOL)isKnownGesture:(NSString *)gesture;
- (NSString *)localizedStringForKey:(NSString *)key;
- (NSString *)titleForGesture:(NSString *)gesture;
- (NSString *)symbolForGesture:(NSString *)gesture;
- (void)saveCurrentGesture:(NSString *)gesture;
- (NSString *)shortcutForGesture:(NSString *)gesture;
- (void)saveShortcut:(NSString *)shortcut forGesture:(NSString *)gesture;
- (NSString *)titleForShortcut:(NSString *)shortcut;
- (BOOL)canUseShortcutForGesture:(NSString *)gesture;
- (NSString *)symbolForShortcut:(NSString *)shortcut;
- (void)recordEvent:(NSString *)event;
- (BOOL)prepareSpringBoardRuntime;
- (BOOL)canHandleButton:(SBRingerHardwareButton *)button;
- (BOOL)executeGesture:(NSString *)gesture onButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event;
- (BOOL)replayNativeActionOnButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event;
- (void)replayNativeTapOnButton:(SBRingerHardwareButton *)button downEvent:(id<AGHardwareButtonEvent>)downEvent upEvent:(id<AGHardwareButtonEvent>)upEvent;
- (void)beginSuppressingSystemActionSnapshots;
- (void)endSuppressingSystemActionSnapshots;
- (void)systemActionPreferenceDidChangeForKey:(NSString *)key;
- (BOOL)hasStoredConfigurationForGesture:(NSString *)gesture;
- (void)initializeEmptyConfigurationForGesture:(NSString *)gesture;
- (void)snapshotNativeConfigurationForGesture:(NSString *)gesture;
- (BOOL)applyNativeConfigurationForGesture:(NSString *)gesture;
- (BOOL)reloadSelectedActionOnButton:(SBRingerHardwareButton *)button;
@end
NS_ASSUME_NONNULL_END
