#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AGHardwareButtonEvent <NSObject>
- (uint64_t)downTime;
@end

@class SBLinkSystemAction;
@class SBSystemActionControl;
@class WFConfiguredStaccatoAction;

@interface SBRingerHardwareButton : NSObject
- (void)performActionsForButtonDown:(id<AGHardwareButtonEvent>)buttonDown;
- (void)performActionsForButtonLongPress:(id<AGHardwareButtonEvent>)longPress;
- (void)performActionsForButtonUp:(id<AGHardwareButtonEvent>)buttonUp;
@end

@interface SBSystemActionAbstractDataSource : NSObject
- (void)setSelectedSystemAction:(nullable SBLinkSystemAction *)systemAction;
- (void)updateSelectedAction;
@end

@interface SBSystemActionControl : NSObject
@end

@interface WFConfiguredStaccatoAction : NSObject <NSSecureCoding>
@end

@interface SBLinkSystemAction : NSObject
- (instancetype)initWithConfiguredAction:
    (WFConfiguredStaccatoAction *)configuredAction;
@end

@interface ActionButtonSettings : UIViewController
@end

@interface ActionButtonSettings (ActionGestureUI)
- (UIButton *)ag_selector:(NSString *)title menu:(UIMenu *)menu;
- (void)ag_installSelectors;
- (UIMenu *)ag_gestureMenu;
- (UIMenu *)ag_shortcutMenu;
@end

NS_ASSUME_NONNULL_END
