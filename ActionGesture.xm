#import <Foundation/Foundation.h>
#import "ActionGestureHelper.h"

static BOOL AGButtonIsDown;
static BOOL AGDidRecognizeLongPress;
static BOOL AGWaitingForSecondTap;
static BOOL AGSecondTapInProgress;
static BOOL AGPassThroughNative;
static NSUInteger AGTapGeneration;
static id<AGHardwareButtonEvent> AGCurrentButtonDownEvent;

%group ActionGestureSpringBoard
%hook SBRingerHardwareButton
- (void)performActionsForButtonDown:(id<AGHardwareButtonEvent>)buttonDown { ActionGestureHelper *h=ActionGestureHelper.sharedHelper; if(![h canHandleButton:self]){AGPassThroughNative=YES;%orig;return;} AGPassThroughNative=NO;AGButtonIsDown=YES;AGDidRecognizeLongPress=NO;AGCurrentButtonDownEvent=buttonDown;AGSecondTapInProgress=AGWaitingForSecondTap;if(AGSecondTapInProgress){AGWaitingForSecondTap=NO;++AGTapGeneration;} }
- (void)performActionsForButtonLongPress:(id<AGHardwareButtonEvent>)longPress { if(AGPassThroughNative){%orig;return;} if(!AGButtonIsDown)return; AGDidRecognizeLongPress=YES;AGWaitingForSecondTap=NO;AGSecondTapInProgress=NO;ActionGestureHelper *h=ActionGestureHelper.sharedHelper;if(![h executeGesture:AGGestureLong onButton:self event:longPress])[h replayNativeActionOnButton:self event:longPress]; }
- (void)performActionsForButtonUp:(id<AGHardwareButtonEvent>)buttonUp { if(AGPassThroughNative){AGPassThroughNative=NO;%orig;return;} if(!AGButtonIsDown)return; BOOL wasLong=AGDidRecognizeLongPress;BOOL second=AGSecondTapInProgress;id<AGHardwareButtonEvent> down=AGCurrentButtonDownEvent;AGButtonIsDown=NO;AGDidRecognizeLongPress=NO;AGSecondTapInProgress=NO;AGCurrentButtonDownEvent=nil;if(wasLong)return;ActionGestureHelper *h=ActionGestureHelper.sharedHelper;if(second){if(![h executeGesture:AGGestureDouble onButton:self event:down])[h replayNativeTapOnButton:self downEvent:down upEvent:buttonUp];return;}AGWaitingForSecondTap=YES;NSUInteger generation=++AGTapGeneration;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,240*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(AGTapGeneration!=generation||!AGWaitingForSecondTap)return;AGWaitingForSecondTap=NO;if(![h executeGesture:AGGestureSingle onButton:self event:down])[h replayNativeTapOnButton:self downEvent:down upEvent:down];}); }
%end
%end
%ctor { @autoreleasepool { if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]&&[ActionGestureHelper.sharedHelper prepareSpringBoardRuntime])%init(ActionGestureSpringBoard); } }
