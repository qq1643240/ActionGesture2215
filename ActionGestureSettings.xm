#import <UIKit/UIKit.h>
#import "ActionGestureHelper.h"

%group ActionGestureOfficialSettings
%hook NSUserDefaults
- (void)setObject:(id)value forKey:(NSString *)key { %orig; [ActionGestureHelper.sharedHelper systemActionPreferenceDidChangeForKey:key]; }
- (void)removeObjectForKey:(NSString *)key { %orig; [ActionGestureHelper.sharedHelper systemActionPreferenceDidChangeForKey:key]; }
%end

%hook ActionButtonSettings
%new - (UIButton *)ag_selector:(NSString *)title menu:(UIMenu *)menu { UIButton *b=[UIButton buttonWithType:UIButtonTypeSystem]; b.titleLabel.font=[UIFont systemFontOfSize:13 weight:UIFontWeightRegular]; [b setTitle:title forState:UIControlStateNormal]; [b setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal]; UIImage *image=[UIImage systemImageNamed:@"chevron.up.chevron.down"]; [b setImage:image forState:UIControlStateNormal]; b.tintColor=[UIColor whiteColor]; b.imageView.preferredSymbolConfiguration=[UIImageSymbolConfiguration configurationWithPointSize:4.5 weight:UIImageSymbolWeightRegular]; b.imageEdgeInsets=UIEdgeInsetsMake(0,2,0,0); b.contentEdgeInsets=UIEdgeInsetsZero; b.menu=menu; b.showsMenuAsPrimaryAction=YES; [b sizeToFit]; return b; }
%new - (void)ag_installSelectors { ActionGestureHelper *h=ActionGestureHelper.sharedHelper; UIButton *g=[self ag_selector:[h titleForGesture:h.currentGesture] menu:[self ag_gestureMenu]]; UIButton *s=[self ag_selector:[h titleForShortcut:[h shortcutForGesture:h.currentGesture]] menu:[self ag_shortcutMenu]]; self.navigationItem.rightBarButtonItems=@[[[UIBarButtonItem alloc]initWithCustomView:s],[[UIBarButtonItem alloc]initWithCustomView:g]]; }
%new - (UIMenu *)ag_gestureMenu { ActionGestureHelper *h=ActionGestureHelper.sharedHelper; NSMutableArray *items=[NSMutableArray array]; for(NSString *g in @[AGGestureSingle,AGGestureDouble,AGGestureLong]) { UIAction *a=[UIAction actionWithTitle:[h titleForGesture:g] image:[UIImage systemImageNamed:[h symbolForGesture:g]] identifier:nil handler:^(__unused UIAction *x){ if([g isEqual:h.currentGesture])return; if(![h hasStoredConfigurationForGesture:h.currentGesture])[h snapshotNativeConfigurationForGesture:h.currentGesture]; if(![h hasStoredConfigurationForGesture:g])[h snapshotNativeConfigurationForGesture:g]; [h saveCurrentGesture:g]; [h applyNativeConfigurationForGesture:g]; [self ag_installSelectors]; }]; a.state=[g isEqual:h.currentGesture]?UIMenuElementStateOn:UIMenuElementStateOff;[items addObject:a]; } return [UIMenu menuWithTitle:@"手势" children:items]; }
%new - (UIMenu *)ag_shortcutMenu { ActionGestureHelper *h=ActionGestureHelper.sharedHelper; NSArray *shortcuts=@[AGShortcutOff,AGShortcutWeChatScan,AGShortcutWeChatPay,AGShortcutAlipayScan,AGShortcutAlipayPay]; NSMutableArray *items=[NSMutableArray array]; for(NSString *s in shortcuts){ UIAction *a=[UIAction actionWithTitle:[h titleForShortcut:s] image:[UIImage systemImageNamed:[h symbolForShortcut:s]] identifier:nil handler:^(__unused UIAction *x){[h saveShortcut:s forGesture:h.currentGesture];[self ag_installSelectors];}];a.state=[s isEqual:[h shortcutForGesture:h.currentGesture]]?UIMenuElementStateOn:UIMenuElementStateOff;[items addObject:a]; } return [UIMenu menuWithTitle:@"快捷动作" children:items]; }
- (void)viewDidLoad { %orig; ActionGestureHelper *h=ActionGestureHelper.sharedHelper; if(![h hasStoredConfigurationForGesture:h.currentGesture])[h snapshotNativeConfigurationForGesture:h.currentGesture]; [self ag_installSelectors]; }
- (void)viewWillAppear:(BOOL)animated { %orig; [self ag_installSelectors]; }
- (void)viewWillDisappear:(BOOL)animated { %orig; }
%end
%end

%ctor { @autoreleasepool { if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.Preferences"]){ActionGestureHelper *h=ActionGestureHelper.sharedHelper;[h loadEditorState];if(!h.settingsBundle.loaded)[h.settingsBundle loadAndReturnError:nil];if(NSClassFromString(@"ActionButtonSettings"))%init(ActionGestureOfficialSettings);} } }
