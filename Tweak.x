#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <SpringBoard/SpringBoard.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/sysctl.h>

// 设置标识符
#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define ENABLED_KEY "enabled"
#define WATERMARK_FOLDER_KEY "watermarkFolder"
#define WATERMARK_OPACITY_KEY "watermarkOpacity"
#define WATERMARK_BLEND_MODE_KEY "watermarkBlendMode"
#define DELETE_ORIGINAL_KEY "deleteOriginal"

// 最大重试次数
#define MAX_RETRY_COUNT 3
// 重试间隔
#define RETRY_INTERVAL 1.0

// 设备验证标志
static BOOL isDeviceAuthorized = NO;

// Base64编码的UDID列表
static NSArray *validBase64UDIDs = nil;

#pragma mark - Base64编码函数
static NSString* base64EncodeString(NSString *string) {
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

#pragma mark - 初始化Base64 UDID列表
static void initializeValidUDIDs() {
    if (!validBase64UDIDs) {
        validBase64UDIDs = @[
            @"MDAwMDgxMjAtMDAxRTNDODYyRTk4QzAxRQ==", // Base64编码的UDID
            @"MDAwMDgxMjAtMDAxQzU0OEEzNkEwQzAxRQ==",
            @"MDAwMDgxMDEtMDAwQTY5NjIyRTMxMDAzQQ==",
            @"MDAwMDgxMjAtMDAxODA4MzQyRUUwMjAxRQ=="
        ];
    }
}

#pragma mark - 动态加载 libMobileGestalt.dylib 获取 UDID
static NSString* getDeviceUDID() {
    NSString *udid = @"";
    
    @try {
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (!handle) {
            NSLog(@"[ScreenshotWatermark] 错误: 无法加载 libMobileGestalt.dylib");
            return @"";
        }
        
        CFStringRef (*MGCopyAnswerFunc)(CFStringRef) = (CFStringRef (*)(CFStringRef))dlsym(handle, "MGCopyAnswer");
        if (!MGCopyAnswerFunc) {
            NSLog(@"[ScreenshotWatermark] 错误: 无法找到 MGCopyAnswer 函数");
            dlclose(handle);
            return @"";
        }

        CFStringRef udidCF = MGCopyAnswerFunc(CFSTR("UniqueDeviceID"));
        dlclose(handle);

        if (!udidCF) {
            NSLog(@"[ScreenshotWatermark] 错误: MGCopyAnswer 返回空值");
            return @"";
        }
        
        udid = (__bridge_transfer NSString *)udidCF;
        NSString *base64UDID = base64EncodeString(udid);
        NSLog(@"[ScreenshotWatermark] 成功获取设备UDID的Base64编码: %@", base64UDID);
    } @catch (NSException *exception) {
        NSLog(@"[ScreenshotWatermark] 获取UDID时发生异常: %@", exception);
        udid = @"";
    }
    
    return udid;
}

#pragma mark - 备用设备标识符获取方法
static NSString* getAlternativeDeviceIdentifier() {
    // 尝试获取其他设备标识符作为备用
    NSString *identifier = @"";
    
    @try {
        // 尝试获取序列号
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        sysctlbyname("hw.machine", machine, &size, NULL, 0);
        identifier = [NSString stringWithUTF8String:machine];
        free(machine);
        
        NSLog(@"[ScreenshotWatermark] 备用设备标识符: %@", identifier);
    } @catch (NSException *exception) {
        NSLog(@"[ScreenshotWatermark] 获取备用设备标识符时发生异常: %@", exception);
    }
    
    return identifier;
}

#pragma mark - 设备验证
static BOOL isValidDevice() {
    initializeValidUDIDs();
    
    NSString *currentUDID = getDeviceUDID();
    
    // 如果UDID获取失败，尝试使用备用标识符
    if ([currentUDID isEqualToString:@""]) {
        NSLog(@"[ScreenshotWatermark] UDID获取失败，尝试使用备用标识符");
        getAlternativeDeviceIdentifier(); // 只调用函数，不存储返回值
        
        // 默认情况下，如果UDID获取失败，拒绝访问
        return NO;
    }
    
    // 将当前UDID转换为Base64进行比较
    NSString *base64CurrentUDID = base64EncodeString(currentUDID);
    BOOL isValid = [validBase64UDIDs containsObject:base64CurrentUDID];
    NSLog(@"[ScreenshotWatermark] 设备验证结果: %@", isValid ? @"通过" : @"失败");
    
    return isValid;
}

// 静态函数：检查文件是否存在
static BOOL fileExists(NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

// 创建目录（如果不存在）
static void createDirectoryIfNotExists(NSString *path) {
    // 只有设备已授权时才创建目录
    if (!isDeviceAuthorized) return;
    
    BOOL isDir;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir]) {
        NSError *error = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:&error];
        if (error) {
            NSLog(@"[ScreenshotWatermark] 创建目录失败: %@, 错误: %@", path, error);
        } else {
            NSLog(@"[ScreenshotWatermark] 已创建目录: %@", path);
        }
    }
}

// 获取设置状态
static BOOL isWatermarkEnabled() {
    // 只有设备已授权时才检查设置
    if (!isDeviceAuthorized) return NO;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    return prefs ? [[prefs objectForKey:@ENABLED_KEY] boolValue] : YES;
}

// 获取用户选择的水印文件夹
static NSString *getSelectedWatermarkFolder() {
    // 只有设备已授权时才获取设置
    if (!isDeviceAuthorized) return nil;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *folder = [prefs objectForKey:@WATERMARK_FOLDER_KEY];
    
    if (!folder || [folder isEqualToString:@"默认水印"] || [folder isEqualToString:@""]) {
        return nil;
    }
    
    return folder;
}

// 获取水印透明度
static CGFloat getWatermarkOpacity() {
    // 只有设备已授权时才获取设置
    if (!isDeviceAuthorized) return 0.6;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSNumber *opacity = [prefs objectForKey:@WATERMARK_OPACITY_KEY];
    
    return opacity ? [opacity floatValue] : 0.6;
}

// 获取水印混合模式
static CGBlendMode getWatermarkBlendMode() {
    // 只有设备已授权时才获取设置
    if (!isDeviceAuthorized) return kCGBlendModeNormal;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *blendMode = [prefs objectForKey:@WATERMARK_BLEND_MODE_KEY];
    
    if (!blendMode) {
        return kCGBlendModeNormal;
    }
    
    if ([blendMode isEqualToString:@"叠加"]) {
        return kCGBlendModeOverlay;
    } else if ([blendMode isEqualToString:@"滤色"]) {
        return kCGBlendModeScreen;
    } else if ([blendMode isEqualToString:@"变亮"]) {
        return kCGBlendModeLighten;
    } else if ([blendMode isEqualToString:@"强光"]) {
        return kCGBlendModeHardLight;
    }
    
    return kCGBlendModeNormal;
}

// 获取删除原图设置
static BOOL shouldDeleteOriginal() {
    // 只有设备已授权时才获取设置
    if (!isDeviceAuthorized) return NO;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    return prefs ? [[prefs objectForKey:@DELETE_ORIGINAL_KEY] boolValue] : NO;
}

// 获取水印图片路径（基于图片方向）
static NSString *getWatermarkPathForImage(UIImage *image) {
    // 只有设备已授权时才获取水印路径
    if (!isDeviceAuthorized) return @"";
    
    NSString *selectedFolder = getSelectedWatermarkFolder();
    NSString *syBasePath = @"/var/mobile/SY";
    
    createDirectoryIfNotExists(syBasePath);
    
    // 根据图片尺寸判断方向
    BOOL isLandscape = image.size.width > image.size.height;
    
    // 根据方向选择水印文件名
    NSString *portraitFilename = @"水印.png";
    NSString *landscapeFilename = @"水印横屏.png";
    NSString *targetFilename = isLandscape ? landscapeFilename : portraitFilename;
    
    NSLog(@"[ScreenshotWatermark] 图片方向: %@, 使用水印文件: %@", 
          isLandscape ? @"横屏" : @"竖屏", targetFilename);
    
    if (selectedFolder) {
        NSString *selectedPath = [syBasePath stringByAppendingPathComponent:selectedFolder];
        NSString *watermarkPath = [selectedPath stringByAppendingPathComponent:targetFilename];
        
        if (fileExists(watermarkPath)) {
            NSLog(@"[ScreenshotWatermark] 使用用户选择的水印文件夹: %@", selectedFolder);
            return watermarkPath;
        } else {
            // 如果方向特定的水印不存在，尝试使用默认水印
            NSString *defaultWatermarkPath = [selectedPath stringByAppendingPathComponent:portraitFilename];
            if (fileExists(defaultWatermarkPath)) {
                NSLog(@"[ScreenshotWatermark] 方向特定水印不存在，使用默认水印: %@", portraitFilename);
                return defaultWatermarkPath;
            }
            NSLog(@"[ScreenshotWatermark] 用户选择的水印文件夹中没有找到水印图片: %@", selectedFolder);
        }
    }
    
    NSError *error = nil;
    NSArray *subdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:&error];
    
    if (error) {
        NSLog(@"[ScreenshotWatermark] 读取SY目录失败: %@", error);
        return [syBasePath stringByAppendingPathComponent:targetFilename];
    }
    
    for (NSString *subdir in subdirectories) {
        NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
        NSString *watermarkPath = [fullPath stringByAppendingPathComponent:targetFilename];
        
        BOOL isDirectory;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory] && 
            isDirectory && 
            fileExists(watermarkPath)) {
            NSLog(@"[ScreenshotWatermark] 找到水印图片在文件夹: %@", subdir);
            return watermarkPath;
        } else {
            // 如果方向特定的水印不存在，尝试使用默认水印
            NSString *defaultWatermarkPath = [fullPath stringByAppendingPathComponent:portraitFilename];
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory] && 
                isDirectory && 
                fileExists(defaultWatermarkPath)) {
                NSLog(@"[ScreenshotWatermark] 方向特定水印不存在，使用默认水印: %@", portraitFilename);
                return defaultWatermarkPath;
            }
        }
    }
    
    NSString *rootWatermarkPath = [syBasePath stringByAppendingPathComponent:targetFilename];
    if (fileExists(rootWatermarkPath)) {
        NSLog(@"[ScreenshotWatermark] 使用根目录水印图片");
        return rootWatermarkPath;
    } else {
        // 如果方向特定的水印不存在，尝试使用默认水印
        NSString *defaultRootWatermarkPath = [syBasePath stringByAppendingPathComponent:portraitFilename];
        if (fileExists(defaultRootWatermarkPath)) {
            NSLog(@"[ScreenshotWatermark] 方向特定水印不存在，使用默认水印: %@", portraitFilename);
            return defaultRootWatermarkPath;
        }
    }
    
    NSString *oldPath = @"/var/mobile/sy/水印.png";
    if (fileExists(oldPath)) {
        NSLog(@"[ScreenshotWatermark] 使用旧路径水印图片");
        return oldPath;
    }
    
    NSLog(@"[ScreenshotWatermark] 未找到水印图片，使用默认路径");
    return [syBasePath stringByAppendingPathComponent:portraitFilename];
}

// 防止重复处理的标志
static BOOL isProcessingScreenshot = NO;
// 重试计数器
static NSUInteger retryCount = 0;

// 静态函数：添加全屏覆盖水印到图片
static UIImage *addWatermarkToImage(UIImage *originalImage) {
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        NSLog(@"[ScreenshotWatermark] 设备未授权或水印功能已关闭，跳过处理");
        return originalImage;
    }
    
    NSLog(@"[ScreenshotWatermark] 开始添加全屏覆盖水印到图片");
    
    NSString *watermarkPath = getWatermarkPathForImage(originalImage);
    
    if (!fileExists(watermarkPath)) {
        NSLog(@"[ScreenshotWatermark] 错误: 水印图片不存在于路径: %@", watermarkPath);
        NSLog(@"[ScreenshotWatermark] 请将水印图片放置在 /var/mobile/SY/任意文件夹/水印.png");
        return originalImage;
    }
    
    UIImage *watermark = [UIImage imageWithContentsOfFile:watermarkPath];
    
    if (!watermark) {
        NSLog(@"[ScreenshotWatermark] 错误: 无法加载水印图片，即使文件存在");
        return originalImage;
    }
    
    NSLog(@"[ScreenshotWatermark] 成功加载水印图片，尺寸: %@", NSStringFromCGSize(watermark.size));
    NSLog(@"[ScreenshotWatermark] 原始图片尺寸: %@", NSStringFromCGSize(originalImage.size));
    
    CGFloat opacity = getWatermarkOpacity();
    CGBlendMode blendMode = getWatermarkBlendMode();
    
    NSLog(@"[ScreenshotWatermark] 使用透明度: %.2f, 混合模式: %d", opacity, blendMode);
    
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    
    [originalImage drawInRect:CGRectMake(0, 0, originalImage.size.width, originalImage.size.height)];
    
    CGFloat targetWidth = originalImage.size.width;
    CGFloat targetHeight = originalImage.size.height;
    
    CGFloat watermarkAspect = watermark.size.width / watermark.size.height;
    CGFloat screenAspect = originalImage.size.width / originalImage.size.height;
    
    if (watermarkAspect > screenAspect) {
        targetWidth = originalImage.size.width;
        targetHeight = targetWidth / watermarkAspect;
    } else {
        targetHeight = originalImage.size.height;
        targetWidth = targetHeight * watermarkAspect;
    }
    
    CGFloat centerX = (originalImage.size.width - targetWidth) / 2.0;
    CGFloat centerY = (originalImage.size.height - targetHeight) / 2.0;
    
    CGRect watermarkRect = CGRectMake(centerX, centerY, targetWidth, targetHeight);
    
    NSLog(@"[ScreenshotWatermark] 水印位置和尺寸: %@", NSStringFromCGRect(watermarkRect));
    
    [watermark drawInRect:watermarkRect blendMode:blendMode alpha:opacity];
    
    UIImage *watermarkedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    NSLog(@"[ScreenshotWatermark] 全屏覆盖水印添加完成");
    return watermarkedImage;
}

// 静态函数：处理最新截图（带重试机制）
static void addWatermarkToLatestScreenshotWithRetry(BOOL isRetry) {
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        NSLog(@"[ScreenshotWatermark] 设备未授权或水印功能已关闭，跳过处理");
        return;
    }
    
    if (isProcessingScreenshot && !isRetry) {
        NSLog(@"[ScreenshotWatermark] 已有截图处理在进行中，跳过本次处理");
        return;
    }
    
    if (!isRetry) {
        isProcessingScreenshot = YES;
        retryCount = 0;
    } else {
        retryCount++;
        if (retryCount >= MAX_RETRY_COUNT) {
            NSLog(@"[ScreenshotWatermark] 已达到最大重试次数，停止尝试");
            isProcessingScreenshot = NO;
            return;
        }
    }
    
    NSLog(@"[ScreenshotWatermark] 开始处理截图%s", isRetry ? " (重试)" : "");
    
    @try {
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status != PHAuthorizationStatusAuthorized) {
            NSLog(@"[ScreenshotWatermark] 警告: 没有相册访问权限，当前状态: %ld", (long)status);
            
            [PHPhotoLibrary requestAuthorization:^(PHAuthorizationStatus status) {
                if (status == PHAuthorizationStatusAuthorized) {
                    NSLog(@"[ScreenshotWatermark] 已获得相册访问权限");
                    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                        addWatermarkToLatestScreenshotWithRetry(YES);
                    });
                } else {
                    NSLog(@"[ScreenshotWatermark] 用户拒绝授予相册访问权限");
                    isProcessingScreenshot = NO;
                }
            }];
            return;
        }
        
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        options.fetchLimit = 5;
        
        // 延长查找时间范围
        NSDate *sixtySecondsAgo = [NSDate dateWithTimeIntervalSinceNow:-60];
        options.predicate = [NSPredicate predicateWithFormat:@"creationDate > %@", sixtySecondsAgo];
        
        PHFetchResult *results = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
        if (results.count == 0) {
            NSLog(@"[ScreenshotWatermark] 未找到任何截图");
            
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                isProcessingScreenshot = NO;
            }
            return;
        }
        
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        CGSize screenshotSize = CGSizeMake(screenSize.width * screenScale, screenSize.height * screenScale);
        
        PHAsset *latestScreenshot = nil;
        
        for (PHAsset *asset in results) {
            if (asset.mediaType == PHAssetMediaTypeImage) {
                // 放宽尺寸匹配条件
                if (asset.pixelWidth >= screenshotSize.width * 0.8 && 
                    asset.pixelWidth <= screenshotSize.width * 1.2 &&
                    asset.pixelHeight >= screenshotSize.height * 0.8 && 
                    asset.pixelHeight <= screenshotSize.height * 1.2) {
                    latestScreenshot = asset;
                    break;
                }
            }
        }
        
        if (!latestScreenshot) {
            NSLog(@"[ScreenshotWatermark] 未找到符合截图尺寸的图片");
            
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                isProcessingScreenshot = NO;
            }
            return;
        }
        
        NSDate *now = [NSDate date];
        NSTimeInterval timeSinceCreation = [now timeIntervalSinceDate:latestScreenshot.creationDate];
        
        // 放宽时间条件
        if (timeSinceCreation > 30) {
            NSLog(@"[ScreenshotWatermark] 最新截图不是最近创建的（%.0f秒前），跳过处理", timeSinceCreation);
            
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                isProcessingScreenshot = NO;
            }
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 找到最新截图，创建于%.0f秒前，尺寸: %lux%lu", 
              timeSinceCreation, (unsigned long)latestScreenshot.pixelWidth, (unsigned long)latestScreenshot.pixelHeight);
        
        PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.version = PHImageRequestOptionsVersionCurrent;
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        requestOptions.synchronous = YES;
        requestOptions.networkAccessAllowed = YES;
        
        [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:latestScreenshot
                                                                        options:requestOptions
                                                                  resultHandler:^(NSData *imageData, NSString *dataUTI, CGImagePropertyOrientation orientation, NSDictionary *info) {
            @try {
                if (imageData) {
                    NSLog(@"[ScreenshotWatermark] 成功获取截图数据");
                    UIImage *screenshot = [UIImage imageWithData:imageData];
                    
                    if (screenshot) {
                        UIImage *watermarkedImage = addWatermarkToImage(screenshot);
                        
                        if (watermarkedImage) {
                            BOOL deleteOriginal = shouldDeleteOriginal();
                            
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                PHAssetChangeRequest *createRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:watermarkedImage];
                                createRequest.creationDate = [NSDate date];
                            } completionHandler:^(BOOL success, NSError *error) {
                                if (success) {
                                    NSLog(@"[ScreenshotWatermark] 已保存带水印的截图到相册");
                                    
                                    if (deleteOriginal) {
                                        [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                            [PHAssetChangeRequest deleteAssets:@[latestScreenshot]];
                                        } completionHandler:^(BOOL success, NSError *error) {
                                            if (success) {
                                                NSLog(@"[ScreenshotWatermark] 已删除原始截图");
                                            } else {
                                                NSLog(@"[ScreenshotWatermark] 删除原始截图失败: %@", error);
                                            }
                                            isProcessingScreenshot = NO;
                                        }];
                                    } else {
                                        isProcessingScreenshot = NO;
                                    }
                                } else {
                                    NSLog(@"[ScreenshotWatermark] 保存失败: %@", error);
                                    isProcessingScreenshot = NO;
                                }
                            }];
                        } else {
                            NSLog(@"[ScreenshotWatermark] 错误: 水印处理失败");
                            isProcessingScreenshot = NO;
                        }
                    } else {
                        NSLog(@"[ScreenshotWatermark] 错误: 无法从数据创建UIImage");
                        isProcessingScreenshot = NO;
                    }
                } else {
                    NSLog(@"[ScreenshotWatermark] 错误: 无法获取截图数据: %@", info);
                    
                    if (!isRetry) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            addWatermarkToLatestScreenshotWithRetry(YES);
                        });
                    } else {
                        isProcessingScreenshot = NO;
                    }
                }
            } @catch (NSException *exception) {
                NSLog(@"[ScreenshotWatermark] 处理截图时发生异常: %@", exception);
                isProcessingScreenshot = NO;
            }
        }];
    } @catch (NSException *exception) {
        NSLog(@"[ScreenshotWatermark] 处理截图时发生异常: %@", exception);
        isProcessingScreenshot = NO;
    }
}

// 包装函数，保持向后兼容
static void addWatermarkToLatestScreenshot() {
    addWatermarkToLatestScreenshotWithRetry(NO);
}

// 设置更改回调函数
static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (!isDeviceAuthorized) return;
    
    NSLog(@"[ScreenshotWatermark] 设置已更改，当前状态: %@", isWatermarkEnabled() ? @"启用" : @"禁用");
    
    NSString *selectedFolder = getSelectedWatermarkFolder();
    if (selectedFolder) {
        NSLog(@"[ScreenshotWatermark] 当前选择的水印文件夹: %@", selectedFolder);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认水印");
    }
    
    CGFloat opacity = getWatermarkOpacity();
    NSLog(@"[ScreenshotWatermark] 当前水印透明度: %.2f", opacity);
    
    CGBlendMode blendMode = getWatermarkBlendMode();
    NSLog(@"[ScreenshotWatermark] 当前水印混合模式: %d", blendMode);
    
    BOOL deleteOriginal = shouldDeleteOriginal();
    NSLog(@"[ScreenshotWatermark] 删除原图设置: %@", deleteOriginal ? @"开启" : @"关闭");
}

// 使用更可靠的截图检测方法
%hook SBScreenshotManager

- (void)saveScreenshots {
    %orig;
    
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到SBScreenshotManager截图保存 (saveScreenshots)");
    
    // 增加延迟时间
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

- (void)saveScreenshotsWithCompletion:(id)completion {
    %orig;
    
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到SBScreenshotManager截图保存 (saveScreenshotsWithCompletion:)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

%end

// Hook SpringBoard 的截图处理方法
%hook SpringBoard

- (void)_handleScreenShot:(id)arg1 {
    %orig;
    
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到截图事件 (_handleScreenShot:)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

- (void)takeScreenshot {
    %orig;
    
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到截图事件 (takeScreenshot)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

// iOS 13+ 的截图方法
- (void)_handlePhysicalButtonEvent:(id)event {
    %orig;
    
    // 检查是否是截图组合键
    BOOL isScreenshot = NO;
    
    // 尝试获取事件类型
    @try {
        NSInteger eventType = [[event valueForKey:@"type"] integerValue];
        NSInteger usagePage = [[event valueForKey:@"usagePage"] integerValue];
        NSInteger usage = [[event valueForKey:@"usage"] integerValue];
        
        NSLog(@"[ScreenshotWatermark] 物理按钮事件: type=%ld, usagePage=%ld, usage=%ld", 
                      (long)eventType, (long)usagePage, (long)usage);
        
        // 检查是否是电源键+音量上键或Home键（截图组合）
        if (eventType == 1 && usagePage == 1) {
            if (usage == 1 || usage == 207) { // 电源键或音量上键
                isScreenshot = YES;
            }
        }
    } @catch (NSException *exception) {
        NSLog(@"[ScreenshotWatermark] 获取事件信息失败: %@", exception);
    }
    
    if (isScreenshot) {
        NSLog(@"[ScreenshotWatermark] 检测到截图组合键");
        
        // 延迟处理，确保截图已保存到相册
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addWatermarkToLatestScreenshot();
        });
    }
}

%end

// 使用通知中心作为备用方法
%ctor {
    // 首先进行设备验证
    isDeviceAuthorized = isValidDevice();
    
    if (!isDeviceAuthorized) {
        NSLog(@"[ScreenshotWatermark] 设备未授权，插件功能已禁用");
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 设备已授权，插件已加载");
    
    createDirectoryIfNotExists(@"/var/mobile/SY");
    
    NSString *defaultWatermarkPath = @"/var/mobile/SY/默认水印";
    createDirectoryIfNotExists(defaultWatermarkPath);
    
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) {
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 检测到截图通知");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addWatermarkToLatestScreenshot();
        });
    }];
    
    [[NSNotificationCenter defaultCenter] addObserverForName:@"com.screenshotwatermark.test" 
                                                      object:nil 
                                                       queue:[NSOperationQueue mainQueue] 
                                                  usingBlock:^(NSNotification *note) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) {
            NSLog(@"[ScreenshotWatermark] 设备未授权或水印功能已关闭，跳过手动测试");
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 手动触发水印添加");
        addWatermarkToLatestScreenshot();
    }];
    
    int token;
    notify_register_dispatch("com.apple.UIKit.screenshotTaken", &token, dispatch_get_main_queue(), ^(int token) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) {
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 检测到Darwin截图通知");
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addWatermarkToLatestScreenshot();
        });
    });
    
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(), 
                                    NULL, 
                                    (CFNotificationCallback)preferencesChanged, 
                                    CFSTR(PREFS_IDENTIFIER "/preferencesChanged"), 
                                    NULL, 
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    NSString *selectedFolder = getSelectedWatermarkFolder();
    if (selectedFolder) {
        NSLog(@"[ScreenshotWatermark] 当前选择的水印文件夹: %@", selectedFolder);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认水印");
    }
    
    CGFloat opacity = getWatermarkOpacity();
    NSLog(@"[ScreenshotWatermark] 当前水印透明度: %.2f", opacity);
    
    CGBlendMode blendMode = getWatermarkBlendMode();
    NSLog(@"[ScreenshotWatermark] 当前水印混合模式: %d", blendMode);
    
    BOOL deleteOriginal = shouldDeleteOriginal();
    NSLog(@"[ScreenshotWatermark] 删除原图设置: %@", deleteOriginal ? @"开启" : @"关闭");
}
