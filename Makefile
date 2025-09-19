ARCHS = arm64 arm64e
INSTALL_TARGET_PROCESSES = SpringBoard
THEOS_PACKAGE_SCHEME = rootless
TARGET = iphone:clang:latest:14.0   # 设置部署目标为 iOS 14.0+

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenshotWatermark
ScreenshotWatermark_FILES = Tweak.x
ScreenshotWatermark_CFLAGS = -fobjc-arc
ScreenshotWatermark_FRAMEWORKS = UIKit Photos AVFoundation CoreMedia MobileCoreServices ReplayKit
ScreenshotWatermark_EXTRA_FRAMEWORKS = Cephei

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += ScreenshotWatermarkPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
