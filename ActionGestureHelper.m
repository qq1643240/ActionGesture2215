#import "ActionGestureHelper.h"
#import <objc/runtime.h>
#import <roothide.h>
#import <unistd.h>
#import <sys/stat.h>

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
@property(nonatomic) dispatch_queue_t shortcutLaunchQueue;
- (SBSystemActionAbstractDataSource *)dataSourceForButton:(SBRingerHardwareButton *)button;
- (NSUserDefaults *)springBoardDefaults;
@end
@implementation ActionGestureHelper
+ (instancetype)sharedHelper { static ActionGestureHelper *h; static dispatch_once_t once; dispatch_once(&once,^{h=[self new];}); return h; }
- (NSString *)actionLogPath { NSString *p=@"/var/tmp/ActionGesture2215.log"; NSFileManager *fm=NSFileManager.defaultManager; NSString *dir=[p stringByDeletingLastPathComponent]; if(![fm fileExistsAtPath:dir]) [fm createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil]; return p; }
- (void)recordEvent:(NSString *)event { if(!event.length)return; NSString *line=[NSString stringWithFormat:@"%@ [pid=%d bundle=%@] %@\n",[NSDate date],getpid(),NSBundle.mainBundle.bundleIdentifier?:@"-",event]; NSData *data=[line dataUsingEncoding:NSUTF8StringEncoding]; static dispatch_queue_t q; static dispatch_once_t once; dispatch_once(&once,^{q=dispatch_queue_create("com.huami.actiongesture.log",DISPATCH_QUEUE_SERIAL);}); dispatch_async(q,^{ NSString *primary=[self actionLogPath]; NSString *mirror=@"/var/tmp/ActionGesture2215.log"; NSMutableArray *paths=[NSMutableArray arrayWithObject:primary]; struct stat a,b; BOOL same=(stat(primary.fileSystemRepresentation,&a)==0&&stat(mirror.fileSystemRepresentation,&b)==0&&a.st_dev==b.st_dev&&a.st_ino==b.st_ino); if(!same&&! [primary isEqualToString:mirror]) [paths addObject:mirror]; for(NSString *path in paths){NSFileHandle *f=[NSFileHandle fileHandleForWritingAtPath:path]; if(!f){[data writeToFile:path atomically:YES];continue;} @try{[f seekToEndOfFile];[f writeData:data];[f closeFile];}@catch(__unused NSException *e){}} }); }
- (instancetype)init { if((self=[super init])) { _currentGesture=AGGestureSingle; _systemActionCache=[NSMutableDictionary dictionary]; _settingsBundle=[NSBundle bundleWithPath:@"/System/Library/PreferenceBundles/ActionButtonSettings.bundle"]; [self recordEvent:@"helper initialized"]; } return self; }
- (id)preferenceValueForKey:(NSString *)key { return CFBridgingRelease(CFPreferencesCopyAppValue((__bridge CFStringRef)key,CFSTR("com.huami.actiongesture"))); }
- (void)setPreferenceValue:(id)value forKey:(NSString *)key { CFPreferencesSetAppValue((__bridge CFStringRef)key,(__bridge CFPropertyListRef)value,CFSTR("com.huami.actiongesture")); }
- (void)sync { CFPreferencesAppSynchronize(CFSTR("com.huami.actiongesture")); }
- (void)loadEditorState { [self sync]; NSString *g=[self preferenceValueForKey:@"editorGesture"]; _currentGesture=[self isKnownGesture:g]?g:AGGestureSingle; }
- (BOOL)isKnownGesture:(NSString *)g { return [@[AGGestureSingle,AGGestureDouble,AGGestureLong] containsObject:g]; }
- (BOOL)isKnownShortcut:(NSString *)s { return [@[AGShortcutOff,AGShortcutWeChatScan,AGShortcutWeChatPay,AGShortcutAlipayScan,AGShortcutAlipayPay] containsObject:s]; }
- (void)saveCurrentGesture:(NSString *)g { if([self isKnownGesture:g]) { _currentGesture=[g copy]; [self setPreferenceValue:g forKey:@"editorGesture"]; [self sync]; [self recordEvent:[NSString stringWithFormat:@"selected gesture=%@",g]]; } }
- (NSString *)shortcutForGesture:(NSString *)g { NSString *s=[self preferenceValueForKey:[NSString stringWithFormat:@"shortcut.%@",g]]; return [self isKnownShortcut:s]?s:AGShortcutOff; }
- (void)saveShortcut:(NSString *)s forGesture:(NSString *)g { if([self isKnownGesture:g]&&[self isKnownShortcut:s]) {[self setPreferenceValue:s forKey:[NSString stringWithFormat:@"shortcut.%@",g]];[self sync];[self recordEvent:[NSString stringWithFormat:@"saved shortcut=%@ gesture=%@",s,g]];} }
- (NSString *)localizedStringForKey:(NSString *)key { NSBundle *b=[NSBundle bundleWithPath:jbroot(@"/Library/Application Support/ActionGesture.bundle")]; return [b localizedStringForKey:key value:key table:nil]; }
- (NSString *)titleForGesture:(NSString *)g { if([g isEqual:AGGestureDouble])return [self localizedStringForKey:@"gesture.double"]; if([g isEqual:AGGestureLong])return [self localizedStringForKey:@"gesture.long"]; return [self localizedStringForKey:@"gesture.single"]; }
- (NSString *)symbolForGesture:(NSString *)g { if([g isEqual:AGGestureDouble])return @"hand.tap.fill"; if([g isEqual:AGGestureLong])return @"hand.point.up.left.fill"; return @"hand.tap"; }
- (NSString *)titleForShortcut:(NSString *)s { NSDictionary *m=@{AGShortcutOff:@"关闭",AGShortcutWeChatScan:@"微信扫码",AGShortcutWeChatPay:@"微信付款",AGShortcutAlipayScan:@"支付宝扫码",AGShortcutAlipayPay:@"支付宝付款"}; return m[s]?:m[AGShortcutOff]; }
- (BOOL)isNoNativeAction:(AGGestureConfiguration *)c { if(!c)return YES; /* iOS 17 keeps an old archive even when the selected system section is cleared. The section identifier is authoritative. */ if(!c.hasSection||!c.sectionIdentifier.length)return YES; NSString *s=c.sectionIdentifier.lowercaseString; return [s containsString:@"none"]||[s containsString:@"noaction"]||[s containsString:@"no_action"]||[s containsString:@"noop"]||[s containsString:@"disabled"]; }
- (NSString *)symbolForShortcut:(NSString *)s { if([s hasSuffix:@"scan"])return @"qrcode.viewfinder"; if([s hasSuffix:@"pay"])return @"creditcard"; return @"bolt.slash"; }

- (BOOL)prepareSpringBoardRuntime { Class c=objc_getClass("SBRingerHardwareButton"); Method d=class_getInstanceMethod(c,@selector(performActionsForButtonDown:)); Method l=class_getInstanceMethod(c,@selector(performActionsForButtonLongPress:)); Method u=class_getInstanceMethod(c,@selector(performActionsForButtonUp:)); if(!c||!d||!l||!u){[self recordEvent:@"runtime hook preparation failed: button methods missing"];return NO;} _originalButtonDown=(AGButtonIMP)method_getImplementation(d); _originalButtonLongPress=(AGButtonIMP)method_getImplementation(l); _originalButtonUp=(AGButtonIMP)method_getImplementation(u); [self recordEvent:@"runtime hook prepared for SBRingerHardwareButton"]; return YES; }
- (BOOL)canHandleButton:(SBRingerHardwareButton *)button { return button && _originalButtonDown && _originalButtonLongPress && _originalButtonUp; }
- (NSUserDefaults *)springBoardDefaults { return [[NSUserDefaults alloc]initWithSuiteName:@"com.apple.springboard"]; }
- (AGGestureConfiguration *)currentNativeConfiguration { NSUserDefaults *d=[self springBoardDefaults]; NSString *section=[d objectForKey:@"SBSystemActionSelectedSectionIdentifier"]; NSData *archive=[d objectForKey:@"SBSystemActionConfiguredActionArchive"]; AGGestureConfiguration *c=[AGGestureConfiguration new]; c.hasSection=[section isKindOfClass:NSString.class]&&section.length>0; c.hasArchive=c.hasSection&&[archive isKindOfClass:NSData.class]; c.sectionIdentifier=c.hasSection?section:nil; c.configuredActionArchive=c.hasArchive?archive:nil; return c; }
- (NSString *)storageKey:(NSString *)g suffix:(NSString *)suffix { return [NSString stringWithFormat:@"native.%@.%@",g,suffix]; }
- (AGGestureConfiguration *)configurationForGesture:(NSString *)g { if(![self isKnownGesture:g])return nil; if(![[self preferenceValueForKey:[self storageKey:g suffix:@"initialized"]] boolValue])return nil; AGGestureConfiguration *c=[AGGestureConfiguration new]; c.hasSection=[[self preferenceValueForKey:[self storageKey:g suffix:@"hasSection"]]boolValue]; c.hasArchive=[[self preferenceValueForKey:[self storageKey:g suffix:@"hasArchive"]]boolValue]; id s=[self preferenceValueForKey:[self storageKey:g suffix:@"section"]]; id a=[self preferenceValueForKey:[self storageKey:g suffix:@"archive"]]; if([s isKindOfClass:NSString.class])c.sectionIdentifier=s; if([a isKindOfClass:NSData.class])c.configuredActionArchive=a; return c; }
- (void)storeConfiguration:(AGGestureConfiguration *)c forGesture:(NSString *)g { if(!c||![self isKnownGesture:g])return; [self setPreferenceValue:@YES forKey:[self storageKey:g suffix:@"initialized"]]; [self setPreferenceValue:@(c.hasSection) forKey:[self storageKey:g suffix:@"hasSection"]]; [self setPreferenceValue:@(c.hasArchive) forKey:[self storageKey:g suffix:@"hasArchive"]]; [self setPreferenceValue:c.hasSection?c.sectionIdentifier:nil forKey:[self storageKey:g suffix:@"section"]]; [self setPreferenceValue:c.hasArchive?c.configuredActionArchive:nil forKey:[self storageKey:g suffix:@"archive"]]; [self sync]; }
- (BOOL)hasStoredConfigurationForGesture:(NSString *)g { return [self configurationForGesture:g]!=nil; }
- (void)snapshotNativeConfigurationForGesture:(NSString *)g { [self storeConfiguration:[self currentNativeConfiguration] forGesture:g]; }
- (BOOL)applyConfiguration:(AGGestureConfiguration *)c { if(!c)return NO; if(!c.hasSection||!c.sectionIdentifier.length)return YES; NSUserDefaults *d=[self springBoardDefaults]; BOOL old=_suppressSystemActionSnapshots; _suppressSystemActionSnapshots=YES; [d setObject:c.sectionIdentifier forKey:@"SBSystemActionSelectedSectionIdentifier"]; if(c.hasArchive&&c.configuredActionArchive)[d setObject:c.configuredActionArchive forKey:@"SBSystemActionConfiguredActionArchive"]; BOOL ok=[d synchronize]; _suppressSystemActionSnapshots=old; return ok; }
- (BOOL)applyNativeConfigurationForGesture:(NSString *)g { return [self applyConfiguration:[self configurationForGesture:g]]; }
- (void)beginSuppressingSystemActionSnapshots { _suppressSystemActionSnapshots=YES; }
- (void)endSuppressingSystemActionSnapshots { _suppressSystemActionSnapshots=NO; }
- (void)systemActionPreferenceDidChangeForKey:(NSString *)key { if(_suppressSystemActionSnapshots)return; if(![key isEqual:@"SBSystemActionSelectedSectionIdentifier"]&&![key isEqual:@"SBSystemActionConfiguredActionArchive"])return; NSString *g=[_currentGesture copy]; dispatch_block_t schedule=^{ self.pendingSnapshotGesture=g; if(self.snapshotScheduled)return; self.snapshotScheduled=YES; dispatch_after(dispatch_time(DISPATCH_TIME_NOW,200*NSEC_PER_MSEC),dispatch_get_main_queue(),^{NSString *p=self.pendingSnapshotGesture;self.pendingSnapshotGesture=nil;self.snapshotScheduled=NO;if(p.length)[self snapshotNativeConfigurationForGesture:p];}); }; if(NSThread.isMainThread)schedule();else dispatch_async(dispatch_get_main_queue(),schedule); }
- (SBSystemActionAbstractDataSource *)dataSourceForButton:(SBRingerHardwareButton *)button { if(!button)return nil; Ivar ci=class_getInstanceVariable([button class],"_systemActionControl"); if(!ci)return nil; id control=object_getIvar(button,ci); if(!control)return nil; Ivar di=class_getInstanceVariable([control class],"_dataSource"); if(!di)return nil; id ds=object_getIvar(control,di); for(NSUInteger i=0;ds&&i<4;i++){Ivar ii=class_getInstanceVariable([ds class],"_innerDataSource");if(!ii)break;id inner=object_getIvar(ds,ii);if(!inner)break;ds=inner;} return ds; }
- (SBLinkSystemAction *)systemActionForConfiguration:(AGGestureConfiguration *)c identifier:(NSString *)identifier { if(!c.hasArchive||!c.configuredActionArchive)return nil; NSDictionary *cached=_systemActionCache[identifier]; if([cached[@"archive"] isEqualToData:c.configuredActionArchive])return cached[@"action"]; NSError *error=nil; WFConfiguredStaccatoAction *configured=nil; @try {configured=[NSKeyedUnarchiver unarchiveTopLevelObjectWithData:c.configuredActionArchive error:&error];}@catch(__unused NSException *e){return nil;} if(!configured||error)return nil; SBLinkSystemAction *a=[(SBLinkSystemAction *)[objc_getClass("SBLinkSystemAction") alloc]initWithConfiguredAction:configured]; if(!a)return nil; _systemActionCache[identifier]=@{@"archive":c.configuredActionArchive,@"action":a}; return a; }
- (BOOL)selectConfiguration:(AGGestureConfiguration *)c identifier:(NSString *)identifier button:(SBRingerHardwareButton *)button { if([self isNoNativeAction:c]){ SBSystemActionAbstractDataSource *ds=[self dataSourceForButton:button]; if([ds respondsToSelector:@selector(setSelectedSystemAction:)])[ds setSelectedSystemAction:nil]; return YES; } if(!c.hasArchive)return YES; SBSystemActionAbstractDataSource *ds=[self dataSourceForButton:button]; if(![ds respondsToSelector:@selector(setSelectedSystemAction:)])return NO; SBLinkSystemAction *a=[self systemActionForConfiguration:c identifier:identifier]; if(!a)return NO; [ds setSelectedSystemAction:a]; return YES; }
- (BOOL)replayNativeActionOnButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if(!_originalButtonDown||!_originalButtonLongPress||!_originalButtonUp||!button||!event)return NO; _originalButtonDown(button,@selector(performActionsForButtonDown:),event);_originalButtonLongPress(button,@selector(performActionsForButtonLongPress:),event); dispatch_after(dispatch_time(DISPATCH_TIME_NOW,120*NSEC_PER_MSEC),dispatch_get_main_queue(),^{self.originalButtonUp(button,@selector(performActionsForButtonUp:),event);});return YES; }
- (NSURL *)shortcutURL:(NSString *)s { if([s isEqual:AGShortcutWeChatScan])return [NSURL URLWithString:@"weixin://scanqrcode"]; if([s isEqual:AGShortcutWeChatPay])return [NSURL URLWithString:@"weixin://widget/pay"]; if([s isEqual:AGShortcutAlipayScan])return [NSURL URLWithString:@"alipay://platformapi/startapp?appId=10000007"]; if([s isEqual:AGShortcutAlipayPay])return [NSURL URLWithString:@"alipay://platformapi/startapp?appId=20000056"]; return nil; }
- (BOOL)openShortcutURL:(NSURL *)url { if(!url)return NO; Class ws=objc_getClass("LSApplicationWorkspace"); id w=ws&&[ws respondsToSelector:@selector(defaultWorkspace)]?[ws defaultWorkspace]:nil; if(!w)return NO; if(!_shortcutLaunchQueue)_shortcutLaunchQueue=dispatch_queue_create("com.huami.actiongesture.shortcut",DISPATCH_QUEUE_SERIAL); [self recordEvent:[NSString stringWithFormat:@"queue shortcut URL=%@",url.absoluteString]]; dispatch_async(_shortcutLaunchQueue,^{ BOOL ok=[w respondsToSelector:@selector(openURL:)]?[w openURL:url]:NO; [self recordEvent:[NSString stringWithFormat:@"shortcut URL %@ result=%@",url.absoluteString,ok?@"success":@"failed"]]; }); return YES; }
- (BOOL)executeGesture:(NSString *)g onButton:(SBRingerHardwareButton *)button event:(id<AGHardwareButtonEvent>)event { if(!button||!event)return NO; AGGestureConfiguration *c=[self configurationForGesture:g]; if(!c){[self snapshotNativeConfigurationForGesture:g];c=[self configurationForGesture:g];} if(!c)return NO; NSString *shortcut=[self shortcutForGesture:g]; BOOL noNative=[self isNoNativeAction:c]; [self recordEvent:[NSString stringWithFormat:@"execute gesture=%@ nativeState=%@ section=%@ archive=%@ archiveBytes=%lu shortcut=%@",g,noNative?@"none":@"present",c.sectionIdentifier?:@"-",c.hasArchive?@"present":@"none",(unsigned long)c.configuredActionArchive.length,shortcut]]; if(noNative){NSURL *url=[self shortcutURL:shortcut];if(url)return [self openShortcutURL:url]; [self recordEvent:@"shortcut is off or URL unavailable"];return NO;} NSString *identifier=g; BOOL selected=[self selectConfiguration:c identifier:identifier button:button]; if(!selected)selected=[self applyConfiguration:c]; [self recordEvent:[NSString stringWithFormat:@"native action replay selected=%@",selected?@"yes":@"no"]]; return selected&&[self replayNativeActionOnButton:button event:event]; }
- (void)replayNativeTapOnButton:(SBRingerHardwareButton *)button downEvent:(id<AGHardwareButtonEvent>)down upEvent:(id<AGHardwareButtonEvent>)up { if(_originalButtonDown&&_originalButtonUp&&button&&down&&up){_originalButtonDown(button,@selector(performActionsForButtonDown:),down);_originalButtonUp(button,@selector(performActionsForButtonUp:),up);} }
@end
