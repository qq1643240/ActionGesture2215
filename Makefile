TARGET := iphone:clang:16.5:15.0
ARCHS = arm64e
THEOS_PACKAGE_SCHEME = roothide
INSTALL_TARGET_PROCESSES = SpringBoard Preferences
export DEBUG = 0
include $(THEOS)/makefiles/common.mk
TWEAK_NAME = ActionGesture
ActionGesture_FILES = ActionGesture.xm ActionGestureSettings.xm ActionGestureHelper.m
ActionGesture_CFLAGS += -fobjc-arc -Wno-deprecated-declarations -fno-modules
ActionGesture_CCFLAGS += -fno-modules -fno-cxx-modules
ActionGesture_FRAMEWORKS += Foundation UIKit
ActionGesture_LIBRARIES += roothide
include $(THEOS_MAKE_PATH)/tweak.mk
