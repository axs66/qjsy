ARCHS = arm64 arm64e
TARGET = iphone:clang:latest:14.0        # 和主 Makefile 保持一致
INSTALL_TARGET_PROCESSES = Preferences   # 对 Preference Bundle 可保留
BUNDLE_NAME = ScreenshotWatermarkPrefs

ScreenshotWatermarkPrefs_FILES = SWPRootListController.m
ScreenshotWatermarkPrefs_FRAMEWORKS = UIKit
ScreenshotWatermarkPrefs_PRIVATE_FRAMEWORKS = Preferences
ScreenshotWatermarkPrefs_INSTALL_PATH = /Library/PreferenceBundles
ScreenshotWatermarkPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ScreenshotWatermarkPrefs.plist$(ECHO_END)
