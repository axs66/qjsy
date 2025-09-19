# 支持通过环境变量切换包类型，默认 rootless
THEOS_PACKAGE_SCHEME ?= rootless

# 架构设置
# 默认只用 64 位，避免 iOS 14.5 32 位报错
ARCHS = arm64 arm64e
# 如果需要支持 32 位，可启用：
# ARCHS = arm arm64 arm64e

INSTALL_TARGET_PROCESSES = SpringBoard
TARGET = iphone:clang:latest:14.5

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ScreenshotWatermark
ScreenshotWatermark_FILES = Tweak.x
ScreenshotWatermark_CFLAGS = -fobjc-arc
ScreenshotWatermark_FRAMEWORKS = UIKit Photos AVFoundation CoreMedia MobileCoreServices ReplayKit

include $(THEOS_MAKE_PATH)/tweak.mk

SUBPROJECTS += ScreenshotWatermarkPrefs
include $(THEOS_MAKE_PATH)/aggregate.mk
