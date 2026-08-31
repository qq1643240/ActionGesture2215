#import "ActionGestureHelper.h"
#import <objc/runtime.h>
#import <roothide.h>

NSString *const AGGestureSingle=@"single";
NSString *const AGGestureDouble=@"double";
NSString *const AGGestureLong=@"long";
NSString *const AGShortcutOff=@"off";
NSString *const AGShortcutWeChatScan=@"wechat.scan";
NSString *const AGShortcutWeChatPay=@"wechat.pay";
NSString *const AGShortcutAlipayScan=@"alipay.scan";
NSString *const AGShortcutAlipayPay=@"alipay.pay";

typedef void (*AGButtonIMP)(SBRingerHardwareButton *,SEL,id<AGHardwareButtonEvent>);

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openURL:(NSURL *)url;
- (BOOL)openSensitiveURL:(NSURL *)url withOptions:(id)options;
@end

@interface AGGestureConfiguration:NSObject
@property(nonatomic) BOOL hasSection;
@property(nonatomic) BOOL hasArchive;
@property(nonatomic,copy) NSString *sectionIdentifier;
@property(nonatomic,copy) NSData *configuredActionArchive;
@end
@implementation AGGestureConfiguration @end

@interface ActionGestureHelper ()
@property(nonatomic,readwrite) NSBundle *settingsBundle;
@property(nonatomic) AGButtonIMP originalButtonDown;
@property(nonatomic) AGButtonIMP originalButtonLongPress;
@property(nonatomic) AGButtonIMP originalButtonUp;
@property(nonatomic) NSMutableDictionary *systemActionCache;
@property(nonatomic) BOOL suppressSystemActionSnapshots;
@property(nonatomic) BOOL snapshotScheduled;
@property(nonatomic,copy) NSString *pendingSnapshotGesture;
- (SBSystemActionAbstractDataSource *)dataSourceForButton:(SBRingerHardwareButton *)button;
- (NSUserDefaults *)springBoardDefaults;
@end
@implementation ActionGestureHelper
+ (instancetype)sharedHelper { static ActionGestureHelper *h; static dispatch_once_t once; dispatch_once(&once,^{h=[self new];}); return h; }
- (instancetype)init { if((self=[super init])) { _currentGesture=AGGestureSingle; _systemActionCache=[NSMutableDictionary dictionary]; _settingsBundle=[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/ActionButtonSettings.bundle"]; } return self; }
- (id)preferenceValueForKey:(NSString *)key { return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,CFSTR("com.huami.actiongesture"))); }
- (void)setPreferenceValue:(id)value forKey:(NSString *)key { CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,CFSTR("com.huami.actiongesture")); }
- (void)sync { CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); }
- (void)loadEditorState { [self sync]; NSString *g=[self preferenceValueForKey:@"editorGesture"]; _currentGesture=[self isKnownGesture:g]?g:AGGestureSingle; }
- (BOOL)isKnownGesture:(NSString *)g { return [@[AGGestureSingle,AGGestureDouble,AGGestureLong] containsObject:g]; }
- (BOOL)isKnownShortcut:(NSString *)s { return [@[AGShortcutOff,AGShortcutWeChatScan,AGShortcutWeChatPay,AGShortcutAlipayScan,AGShortcutAlipayPay] containsObject:s]; }
- (void)saveCurrentGesture:(NSString *)g { if([self isKnownGesture:g]) { _currentGesture=[g copy]; [self setPreferenceValue:g forKey:@"editorGesture"]; [self sync]; } }
- (NSString *)shortcutForGesture:(NSString *)g { NSString *s=[self preferenceValueForKey:[NSString stringWithFormat:@"shortcut.%@",g]]; return [self isKnownShortcut:s]?s:AGShortcutOff; }
- (void)saveShortcut:(NSString *)s forGesture:(NSString *)g { if([self isKnownGesture:g]&&[self isKnownShortcut:s]) {[self setPreferenceValue:s forKey:[NSString stringWithFormat:@"shortcut.%@",g]];[self sync];} }
- (NSString *)localizedStringForKey:(NSString *)key { NSBundle *b=[NSBundle bundleWithPath:jbroot(@"/Library/Application Support/ActionGesture.bundle")]; return [b localizedStringForKey:key value:key table:nil]; }
- (NSString *)titleForGesture:(NSString *)g { if([g isEqual:AGGestureDouble])return [self localizedStringForKey:@"gesture.double"]; if([g isEqual:AGGestureLong])return [self localizedStringForKey:@"gesture.long"]; return [self localizedStringForKey:@"gesture.single"]; }
- (NSString *)symbolForGesture:(NSString *)g { if([g isEqual:AGGestureDouble])return @"hand.tap.fill"; if([g isEqual:AGGestureLong])return @"hand.point.up.left.fill"; return @"hand.tap"; }
- (NSString *)titleForShortcut:(NSString *)s { NSDictionary *m=@{AGShortcutOff:@"关闭",AGShortcutWeChatScan:@"微信扫码",AGShortcutWeChatPay:@"微信付款",AGShortcutAlipayScan:@"支付宝扫码",AGShortcutAlipayPay:@"支付宝付款"}; return m[s]?:m[AGShortcutOff]; }
- (NSString *)symbolForShortcut:(NSString *)s { if([s hasSuffix:@"scan"])return @"qrcode.viewfinder"; if([s hasSuffix:@"pay"])return @"creditcard"; return @"bolt.slash"; }

- (BOOL)prepareSpringBoardRuntime { Class c=objc_getClass("SBRingerHardwareButton"); Method d=class_getInstanceMethod(c,@selector(performActionsForButtonDown:)); Method l=class_getInstanceMethod(c,@selector(performActionsForButtonLongPress:)); Method u=class_getInstanceMethod(c,@selector(performActionsForButtonUp:)); if(!c||!d||!l||!u)return NO; _originalButtonDown=(AGButtonIMP)method_getImplementation(d); _originalButtonLongPress=(AGButtonIMP)method_getImplementation(l); _originalButtonUp=(AGButtonIMP)method_getImplementation(u); return YES; }
- (BOOL)canHandleButton:(SBRingerHardwareButton *)button { return button && _originalButtonDown && _originalButtonLongPress && _originalButtonUp; }
- (NSUserDefaults *)springBoardDefaults { return [[NSUserDefaults alloc]initWithSuiteName:@"com.apple.springboard"]; }
- (AGGestureConfiguration *)currentNativeConfiguration { NSUserDefaults *d=[self springBoardDefaults]; NSString *section=[d objectForKey:@"SBSystemActionSelectedSectionIdentifier"]; NSData *archive=[d objectForKey:@"SBSystemActionConfiguredActionArchive"]; AGGestureConfiguration *c=[AGGestureConfiguration new]; c.hasSection=[section isKindOfClass:NSString.class]; c.hasArchive=[archive isKindOfClass:NSData.class]; c.sectionIdentifier=c.hasSection?section:nil; c.configuredActionArchive=c.hasArchive?archive:nil; return c; }
- (NSString *)storageKey:(NSString *)g suffix:(NSString *)suffix { return [NSString stringWithFormat:@"native.%@.%@",g,suffix]; }
- (AGGestureConfiguration *)configurationForGesture:(NSString *)g { if(![self isKnownGesture:g])return nil; if(![[self preferenceValueForKey:[self storageKey:g suffix:@"initialized"]] boolValue])return nil; AGGestureConfiguration *c=[AGGestureConfiguration new]; c.hasSection=[[self preferenceValueForKey:[self storageKey:g suffix:@"hasSection"]]boolValue]; c.hasArchive=[[self preferenceValueForKey:[self storageKey:g suffix:@"hasArchive"]]boolValue]; id s=[self preferenceValueForKey:[self storageKey:g suffix:@"section"]]; id a=[self preferenceValueForKey:[self storageKey:g suffix:@"archive"]]; if([s isKindOfClass:NSString.class])c.sectionIdentifier=s; if([a isKindOfClass:NSData.class])c.configuredActionArchive=a; return c; }
- (void)storeConfiguration:(AGGestureConfiguration *)c forGesture:(NSString *)g { if(!c||![self isKnownGesture:g])return; [self setPreferenceValue:@YES forKey:[self storageKey:g suffix:@"initialized"]]; [self setPreferenceValue:@(c.hasSection) forKey:[self storageKey:g suffix:@"hasSection"]]; [self setPreferenceValue:@(c.hasArchive) forKey:[self storageKey:g suffix:@"hasArchive"]]; [self setPreferenceValue:c.hasSection?c.sectionIdentifier:nil forKey:[self storageKey:g suffix:@"section"]]; [self setPreferenceValue:c.hasArchive?c.configuredActionArchive:nil forKey:[self storageKey:g suffix:@"archive"]]; [self sync]; }
- (BOOL)hasStoredConfigurationForGesture:(NSString *)g { return [self configurationForGesture:g]!=nil; }
- (void)snapshotNativeConfigurationForGesture:(NSString *)g { [self storeConfiguration:[self currentNativeConfiguration] forGesture:g]; }
- (BOOL)applyConfiguration:(AGGestureConfiguration *)c { if(!c)return NO; NSUserDefaults *d=[self springBoardDefaults]; BOOL old=_suppressSystemActionSnapshots; _suppressSystemActionSnapshots=YES; if(c.hasSection&&c.sectionIdentifier)[d setObject:c.sectionIdentifier forKey:@"SBSystemActionSelectedSectionIdentifier"];else [d removeObjectForKey:@"SBSystemActionSelectedSectionIdentifier"]; if(c.hasArchive&&c.configuredActionArchive)[d setObject:c.configuredActionArchive forKey:@"SBSystemActionConfiguredActionArchive"];else [d removeObjectForKey:@"SBSystemActionConfiguredActionArchive"]; BOOL ok=[d synchronize]; _suppressSystemActionSnapshots=old; return ok; }
- (BOOL)applyNativeConfigurationForGesture:(NSString *)g { return [self applyConfiguration:[self configurationForGesture:g]]; }
- (void)beginSuppressingSystemActionSnapshots { _suppressSystemActionSnapshots=YES; }
- (void)endSuppressingSystemActionSnapshots { _suppressSystemActionSnapshots=NO; }
- (void)systemActionPreferenceDidChangeForKey:(NSString *)key { if(_suppressSystemActionSnapshots)return; if(![key isEqual:@"SBSystemActionSelectedSectionIdentifier"]&&![key isEqual:@"SBSystemActionConfiguredActionArchive"])return; NSString *g=_currentGesture; dispatch_async(dispatch_get_main_queue(),^{ if(!self.snapshotScheduled){self.snapshotScheduled=YES; self.pendingSnapshotGesture=g; dispatch_async(dispatch_get_main_queue(),^{NSString *p=self.pendingSnapshotGesture;self.pendingSnapshotGesture=nil;self.snapshotScheduled=NO;[self snapshotNativeConfigurationForGesture:p];});} }); }
- (SBSystemActionAbstractDataSource *)dataSourceForButton:(SBRingerHardwareButton *)button { Ivar ci=class_getInstanceVariable(object_getClass(button),"_systemActionControl"); if(!ci)return nil; id control=object_getIvar(button,ci); Ivar di=class_getInstanceVariable(object_getClass(control),"_dataSource"); if(!di)return nil; id ds=object_getIvar(control,di); for(NSUInteger i=0;ds&&i<4;i++){Ivar ii=class_getInstanceVariable(object_getClass(ds),"_innerDataSource");if(!ii)break;id inner=object_getIvar(ds,ii);if(!inner)break;ds=inner;} return ds; }
- (SBLinkSystemAction *)systemActionForConfiguration:(AGGestureConfiguration *)c identifier:(NSString *)identifier { if(!c.hasArchive||!c.configuredActionArchive)return nil; NSDictionary *cached=_systemActionCache[identifier]; if([cached[@"archive"] isEqualToData:c.configuredActionArchive])return cached[@"action"]; NSError *error=nil; WFConfiguredStaccatoAction *configured=nil; @try {configured=[NSKeyedUnarchiver unarchiveTopLevelObjectWithData:c.configuredActionArchive error:&error];}@catch(__unused NSException *e){return nil;} if(!configured||error)return nil; SBLinkSystemAction *a=[(SBLinkSystemAction *)[objc_getClass("SBLinkSystemAction") alloc]initWithConfiguredAction:configured]; if(!a)return nil; _systemActionCache[identifier]=@{@"archive":c.configuredActionArchive,@"action":a}; return a; }
- (BOOL)selectConfiguration:(AGGestureConfiguration *)c identifier:(NSString *)identifier button:(SBRingerHardwareButton *)button { SBSystemActionAbstractDataSource *ds=[self dataSourceForButton:button]; if(![ds respondsToSelector:@selector(setSelectedSystemAction:)])return NO; if(!c.hasArchive){[ds setSelectedSystemAction:nil];return YES;} SBLinkSystemAction *a=[self systemActionForConfiguration:c identifier:identifier]; if(!a)return NO; [ds setSelectedSystemAction:a]; return YES; }
- (BOOL)replayNativeActionOnButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if(!_originalButtonDown||!_originalButtonLongPress||!_originalButtonUp||!button||!event)return NO; _originalButtonDown(button,@selector(performActionsForButtonDown:),event);_originalButtonLongPress(button,@selector(performActionsForButtonLongPress:),event); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{self.originalButtonUp(button,@selector(performActionsForButtonUp:),event);});return YES; }
- (NSURL *)shortcutURL:(NSString *)s { if([s isEqual:AGShortcutWeChatScan])return [NSURL URLWithString:@"weixin://scanqrcode"]; if([s isEqual:AGShortcutWeChatPay])return [NSURL URLWithString:@"weixin://dl/businessPay"]; if([s isEqual:AGShortcutAlipayScan])return [NSURL URLWithString:@"alipayqr://platformapi/startapp?saId=10000007"]; if([s isEqual:AGShortcutAlipayPay])return [NSURL URLWithString:@"alipays://platformapi/startapp?appId=20000056"]; return nil; }
- (BOOL)openShortcutURL:(NSURL *)url { if(!url)return NO; Class ws=objc_getClass("LSApplicationWorkspace"); id w=ws&&[ws respondsToSelector:@selector(defaultWorkspace)]?[ws defaultWorkspace]:nil; BOOL ok=NO; if([w respondsToSelector:@selector(openSensitiveURL:withOptions:)])ok=[w openSensitiveURL:url withOptions:nil]; if(!ok&&[w respondsToSelector:@selector(openURL:)])ok=[w openURL:url]; if(!ok){UIApplication *app=UIApplication.sharedApplication;if([app respondsToSelector:@selector(openURL:options:completionHandler:)]){[app openURL:url options:@{} completionHandler:nil];ok=YES;}} return ok; }
- (BOOL)executeGesture:(NSString *)g onButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if(!button||!event)return NO; AGGestureConfiguration *c=[self configurationForGesture:g]; if(!c){[self snapshotNativeConfigurationForGesture:g];c=[self configurationForGesture:g];} if(!c)return NO; /* Native action wins. A shortcut is eligible only when no native action archive exists. */ if(!c.hasArchive){NSURL *url=[self shortcutURL:[self shortcutForGesture:g]];if(url){dispatch_async(dispatch_get_main_queue(),^{[self openShortcutURL:url];});return YES;}} NSString *identifier=g; BOOL selected=[self selectConfiguration:c identifier:identifier button:button]; if(!selected)selected=[self applyConfiguration:c]; return selected&&[self replayNativeActionOnButton:button event:event]; }
- (void)replayNativeTapOnButton:(SBRingerHardwareButton *)button downEvent:(id<AGHardwareButtonEvent>)down upEvent:(id<AGHardwareButtonEvent>)up { if(_originalButtonDown&&_originalButtonUp&&button&&down&&up){_originalButtonDown(button,@selector(performActionsForButtonDown:),down);_originalButtonUp(button,@selector(performActionsForButtonUp:),up);} }
@end
