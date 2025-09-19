ARCHS = arm6 arm64 arm64e
TARGET := iphone:clang:latest:14.5
INSTALL_TARGET_PROCESSES = Preferences

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = ScreenshotWatermarkPrefs

ScreenshotWatermarkPrefs_FILES = SWPRootListController.m
ScreenshotWatermarkPrefs_FRAMEWORKS = UIKit
ScreenshotWatermarkPrefs_PRIVATE_FRAMEWORKS = Preferences
ScreenshotWatermarkPrefs_INSTALL_PATH = /Library/PreferenceBundles
ScreenshotWatermarkPrefs_CFLAGS = -fobjc-arc
SDKROOT = $(THEOS)/sdks/iPhoneOS14.5.sdk
ScreenshotWatermarkPrefs_LDFLAGS = -L$(SDKROOT)/usr/lib -F$(SDKROOT)/System/Library/PrivateFrameworks


include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ScreenshotWatermarkPrefs.plist$(ECHO_END)
