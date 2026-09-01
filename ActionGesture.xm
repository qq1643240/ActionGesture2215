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
- (void)performActionsForButtonDown:(id<AGHardwareButtonEvent>)buttonDown { ActionGestureHelper *h=ActionGestureHelper.sharedHelper; [h recordEvent:@"button down"]; if(![h canHandleButton:self]){AGPassThroughNative=YES;%orig;return;} AGPassThroughNative=NO;AGButtonIsDown=YES;AGDidRecognizeLongPress=NO;AGCurrentButtonDownEvent=buttonDown;AGSecondTapInProgress=AGWaitingForSecondTap;if(AGSecondTapInProgress){AGWaitingForSecondTap=NO;++AGTapGeneration;} }
- (void)performActionsForButtonLongPress:(id<AGHardwareButtonEvent>)longPress { if(AGPassThroughNative){%orig;return;} if(!AGButtonIsDown)return; AGDidRecognizeLongPress=YES;AGWaitingForSecondTap=NO;AGSecondTapInProgress=NO;++AGTapGeneration;ActionGestureHelper *h=ActionGestureHelper.sharedHelper;[h recordEvent:@"button long press"];id<AGHardwareButtonEvent> event=[longPress respondsToSelector:@selector(downTime)]?longPress:AGCurrentButtonDownEvent;if(![h executeGesture:AGGestureLong onButton:self event:event])[h replayNativeActionOnButton:self event:event]; }
- (void)performActionsForButtonUp:(id<AGHardwareButtonEvent>)buttonUp { if(AGPassThroughNative){AGPassThroughNative=NO;%orig;return;} if(!AGButtonIsDown)return; ActionGestureHelper *h=ActionGestureHelper.sharedHelper;[h recordEvent:@"button up"]; BOOL wasLong=AGDidRecognizeLongPress;BOOL second=AGSecondTapInProgress;id<AGHardwareButtonEvent> down=AGCurrentButtonDownEvent;AGButtonIsDown=NO;AGDidRecognizeLongPress=NO;AGSecondTapInProgress=NO;AGCurrentButtonDownEvent=nil;if(wasLong){++AGTapGeneration;return;}if(second){[h recordEvent:@"double tap recognized"];if(![h executeGesture:AGGestureDouble onButton:self event:down])[h replayNativeTapOnButton:self downEvent:down upEvent:buttonUp];return;}AGWaitingForSecondTap=YES;NSUInteger generation=++AGTapGeneration;id<AGHardwareButtonEvent> up=buttonUp;dispatch_after(dispatch_time(DISPATCH_TIME_NOW,240*NSEC_PER_MSEC),dispatch_get_main_queue(),^{if(AGTapGeneration!=generation||!AGWaitingForSecondTap)return;AGWaitingForSecondTap=NO;[h recordEvent:@"single tap recognized"];if(![h executeGesture:AGGestureSingle onButton:self event:down])[h replayNativeTapOnButton:self downEvent:down upEvent:up];}); }
%end
%end
%ctor { @autoreleasepool { if([NSBundle.mainBundle.bundleIdentifier isEqual:@"com.apple.springboard"]&&[ActionGestureHelper.sharedHelper prepareSpringBoardRuntime])%init(ActionGestureSpringBoard); } }
