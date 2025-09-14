#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <SpringBoard/SpringBoard.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <CoreFoundation/CoreFoundation.h>

// 设置标识符
#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define ENABLED_KEY "enabled"
#define WATERMARK_FOLDER_KEY "watermarkFolder"
#define WATERMARK_OPACITY_KEY "watermarkOpacity"
#define WATERMARK_BLEND_MODE_KEY "watermarkBlendMode"
#define DELETE_ORIGINAL_KEY "deleteOriginal"

// 最大重试次数
#define MAX_RETRY_COUNT 3
// 重试间隔（秒）
#define RETRY_INTERVAL 1.0

// 设备验证标志
static BOOL isDeviceAuthorized = NO;

// Base64编码的UDID列表（保持你原有的白名单）
static NSArray *validBase64UDIDs = nil;

#pragma mark - helpers

static NSString* base64EncodeString(NSString *string) {
    if (!string) return nil;
    NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
    return [data base64EncodedStringWithOptions:0];
}

static void initializeValidUDIDs() {
    if (!validBase64UDIDs) {
        validBase64UDIDs = @[
            @"MDAwMDgxMjAtMDAxQzU0OEEzNkEwQzAxRQ==",
            @"MDAwMDgxMjAtMDAxRTY0RDgzRUEwQzAxRQ==",
            @"MDAwMDgxMjAtMDAxNDE4OTgzQzk4MjAxRQ==",
            @"MDAwMDgxMjAtMDAxMTA5NTYwQUUwQzAxRQ==",
            @"MDAwMDgxMjAtMDAwQTQxMDAzNDIyMjAxRQ==",
            @"MDAwMDgxMjAtMDAxRTNDODYyRTk4QzAxRQ==",
            @"MDAwMDgxMjAtMDAwMjA5OUMzQzdCQzAxRQ==",
            @"MDAwMDgxMjAtMDAxQzFDMzAxRTY4MjAxRQ==",
            @"MDAwMDgxMTAtMDAwODQ5NEEzQ0I5ODAxRQ==",
            @"MDAwMDgxMjAtMDAxQzYwQzIzNjEzQzAxRQ==",
            @"MDAwMDgxMTAtMDAxQTU4NTAyMjIxODAxRQ==",
            @"MDAwMDgxMTAtMDAxQzQ1QTQxNEExNDAxRQ==",
            @"MDAwMDgwMzAtMDAwMzU4OTIxNERBNDAyRQ==",
            @"MDAwMDgxMjAtMDAxNjE0NjkyMTQ3NDAxRQ==",
            @"MDAwMDgxMjAtMDAxQTA5OTQyRTk4MjAxRQ==",
            @"MDAwMDgxMDEtMDAxQzRDMkMzQTgyMDAxRQ==",
            @"MDAwMDgxMDEtMDAwMDU4NkEwMTY4MDAxRQ==",
            @"MDAwMDgxMjAtMDAwMjREQzEwQUYzQzAxRQ==",
            @"MDAwMDgxMjAtMDAwQzU1MDYyMjQ0QzAxRQ==",
            @"MDAwMDgxMjAtMDAwMTU1OTQyRUUwMjAxRQ==",
            @"MDAwMDgxMjAtMDAwMTcxMTEyMUYwMjAxRQ==",
            @"MDAwMDgxMjAtMDAwMjA5OUMzQzdCQzAxRQ==",
            @"MDAwMDgxMjAtMDAxNDJEMDYyMjY4MjAxRQ==",
            @"MDAwMDgxMjAtMDAwNDM0QzExRTk4MjAxRQ==",
            @"MDAwMDgxMjAtMDAxQzYwQzIzNjEzQzAxRQ==",
            @"MDAwMDgxMDEtMDAxQzRDMkMzQTgyMDAxRQ==",
            @"MDAwMDgxMjAtMDAwMjREQzEwQUYzQzAxRQ==",
            @"MDAwMDgxMDEtMDAwQTY5NjIyRTMxMDAzQQ==",
            @"MDAwMDgxMDEtMDAwMDU4NkEwMTY4MDAxRQ==",
            @"MDAwMDgxMjAtMDAxRTJDQTIzNkRCNDAxRQ==",
            @"MDAwMDgxMDEtMDAwMDU4NkEwMTY4MDAxRQ==",
            @"MDAwMDgxMDEtMDAwQTY5NjIyRTMxMDAzQQ==",
            @"MDAwMDgxMTAtMDAxNDUwNkMzNDgyODAxRQ==",
            @"MDAwMDgxMjAtMDAxRTJDQTIzNkRCNDAxRQ==",
            @"MDAwMDgxMjAtMDAxNjM1QzgzQTgwMjAxRQ==",
            @"MDAwMDgxMTAtMDAwNDcxMzkxNDgyNDAxRQ==",
            @"MDAwMDgxMjAtMDAwNjI0NTAwQzdCQzAxRQ==",
            @"MDAwMDgxMjAtMDAxRTJDQTIzNkRCNDAxRQ=="
        ];
    }
}

#pragma mark - 获取偏好（用 CFPreferences，兼容性更好）
static CFStringRef cfStringFromCStr(const char *cstr) {
    if (!cstr) return NULL;
    return CFStringCreateWithCString(kCFAllocatorDefault, cstr, kCFStringEncodingUTF8);
}

static id getPrefObjectForKey(const char *key_cstr) {
    if (!key_cstr) return nil;
    CFStringRef key = cfStringFromCStr(key_cstr);
    CFStringRef appID = cfStringFromCStr(PREFS_IDENTIFIER);
    if (!key || !appID) {
        if (key) CFRelease(key);
        if (appID) CFRelease(appID);
        return nil;
    }
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, appID);
    CFRelease(key);
    CFRelease(appID);
    if (!value) return nil;
    id objcValue = CFBridgingRelease((CFTypeRef)CFRetain(value));
    CFRelease(value);
    return objcValue;
}

#pragma mark - 更稳健的 MGCopyAnswer (dlopen + dlsym) + fallback 到 identifierForVendor
static NSString* getDeviceUDID() {
    NSString *udid = nil;
    
    @try {
        void *handle = dlopen("/usr/lib/libMobileGestalt.dylib", RTLD_LAZY);
        if (handle) {
            // MGCopyAnswer signature: CFTypeRef MGCopyAnswer(CFStringRef);
            CFTypeRef (*MGCopyAnswerFunc)(CFStringRef) = (CFTypeRef (*)(CFStringRef))dlsym(handle, "MGCopyAnswer");
            if (MGCopyAnswerFunc) {
                CFTypeRef ret = MGCopyAnswerFunc(CFSTR("UniqueDeviceID"));
                if (ret && CFGetTypeID(ret) == CFStringGetTypeID()) {
                    udid = [NSString stringWithString:(__bridge_transfer NSString *)ret];
                } else if (ret) {
                    CFRelease(ret);
                }
            } else {
                NSLog(@"[ScreenshotWatermark] dlsym: MGCopyAnswer 未找到");
            }
            dlclose(handle);
        } else {
            // dlopen 失败，但这在新系统中可能仍可通过 shared cache 解析，尝试 dlsym(NULL,...)
            CFTypeRef (*MGCopyAnswerFunc2)(CFStringRef) = (CFTypeRef (*)(CFStringRef))dlsym(RTLD_DEFAULT, "MGCopyAnswer");
            if (MGCopyAnswerFunc2) {
                CFTypeRef ret = MGCopyAnswerFunc2(CFSTR("UniqueDeviceID"));
                if (ret && CFGetTypeID(ret) == CFStringGetTypeID()) {
                    udid = [NSString stringWithString:(__bridge_transfer NSString *)ret];
                } else if (ret) {
                    CFRelease(ret);
                }
            } else {
                NSLog(@"[ScreenshotWatermark] dlopen/dlsym 都无法取得 MGCopyAnswer");
            }
        }
    } @catch (NSException *e) {
        NSLog(@"[ScreenshotWatermark] 获取UDID发生异常: %@", e);
        udid = nil;
    }
    
    // fallback 到 identifierForVendor
    if (!udid || udid.length == 0) {
        @try {
            NSString *idfv = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
            if (idfv && idfv.length > 0) {
                udid = idfv;
                NSLog(@"[ScreenshotWatermark] 使用 identifierForVendor 作为备用 UDID: %@", udid);
            }
        } @catch (NSException *e) {
            NSLog(@"[ScreenshotWatermark] fallback identifierForVendor 异常: %@", e);
        }
    } else {
        NSLog(@"[ScreenshotWatermark] 成功通过 MGCopyAnswer 获取 UDID（未编码）");
    }
    
    if (!udid) return @"";
    return udid;
}

#pragma mark - 备用设备标识符（保留，作日志用途）
static NSString* getAlternativeDeviceIdentifier() {
    NSString *identifier = @"";
    @try {
        size_t size;
        sysctlbyname("hw.machine", NULL, &size, NULL, 0);
        char *machine = malloc(size);
        if (machine) {
            sysctlbyname("hw.machine", machine, &size, NULL, 0);
            identifier = [NSString stringWithUTF8String:machine] ?: @"";
            free(machine);
        }
    } @catch (NSException *e) {
        NSLog(@"[ScreenshotWatermark] 获取备用设备标识符异常: %@", e);
    }
    return identifier;
}

#pragma mark - 设备验证
static BOOL isValidDevice() {
    initializeValidUDIDs();
    
    NSString *currentUDID = getDeviceUDID();
    if (!currentUDID || [currentUDID isEqualToString:@""]) {
        NSLog(@"[ScreenshotWatermark] UDID获取失败，尝试备用标识符");
        NSString *alt = getAlternativeDeviceIdentifier();
        if (alt && alt.length > 0) {
            NSLog(@"[ScreenshotWatermark] 备用标识符: %@", alt);
        }
        return NO;
    }
    
    NSString *base64CurrentUDID = base64EncodeString(currentUDID);
    BOOL isValid = [validBase64UDIDs containsObject:base64CurrentUDID];
    NSLog(@"[ScreenshotWatermark] 当前UDID(base64): %@ -> 验证结果: %@", base64CurrentUDID, isValid ? @"通过" : @"失败");
    return isValid;
}

#pragma mark - 文件/目录工具
static BOOL fileExists(NSString *path) {
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

static void createDirectoryIfNotExists(NSString *path) {
    if (!path || path.length == 0) return;
    BOOL isDir = NO;
    if (![[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDir] || !isDir) {
        NSError *err = nil;
        [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:&err];
        if (err) {
            NSLog(@"[ScreenshotWatermark] 创建目录失败 %@: %@", path, err);
        } else {
            NSLog(@"[ScreenshotWatermark] 创建目录: %@", path);
        }
    }
}

#pragma mark - 读取偏好（更安全）
static BOOL prefBoolForKey(const char *key_cstr, BOOL defaultValue) {
    id v = getPrefObjectForKey(key_cstr);
    if (!v) return defaultValue;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber*)v boolValue];
    if ([v isKindOfClass:[NSString class]]) return ([(NSString*)v boolValue]);
    return defaultValue;
}
static NSString *prefStringForKey(const char *key_cstr, NSString *defaultValue) {
    id v = getPrefObjectForKey(key_cstr);
    if (!v) return defaultValue;
    if ([v isKindOfClass:[NSString class]]) return v;
    if ([v isKindOfClass:[NSNumber class]]) return [v stringValue];
    return defaultValue;
}
static CGFloat prefFloatForKey(const char *key_cstr, CGFloat defaultValue) {
    id v = getPrefObjectForKey(key_cstr);
    if (!v) return defaultValue;
    if ([v isKindOfClass:[NSNumber class]]) return [(NSNumber*)v floatValue];
    if ([v isKindOfClass:[NSString class]]) return [(NSString*)v floatValue];
    return defaultValue;
}

#pragma mark - 偏好接口（以 isDeviceAuthorized 为前提）
static BOOL isWatermarkEnabled() {
    if (!isDeviceAuthorized) return NO;
    return prefBoolForKey(ENABLED_KEY, YES);
}
static NSString *getSelectedWatermarkFolder() {
    if (!isDeviceAuthorized) return nil;
    NSString *folder = prefStringForKey(WATERMARK_FOLDER_KEY, nil);
    if (!folder || [folder isEqualToString:@"默认水印"] || folder.length == 0) return nil;
    return folder;
}
static CGFloat getWatermarkOpacity() {
    if (!isDeviceAuthorized) return 0.6;
    return prefFloatForKey(WATERMARK_OPACITY_KEY, 0.6f);
}
static CGBlendMode getWatermarkBlendMode() {
    if (!isDeviceAuthorized) return kCGBlendModeNormal;
    NSString *blendMode = prefStringForKey(WATERMARK_BLEND_MODE_KEY, nil);
    if (!blendMode) return kCGBlendModeNormal;
    if ([blendMode isEqualToString:@"叠加"]) return kCGBlendModeOverlay;
    if ([blendMode isEqualToString:@"滤色"]) return kCGBlendModeScreen;
    if ([blendMode isEqualToString:@"变亮"]) return kCGBlendModeLighten;
    if ([blendMode isEqualToString:@"强光"]) return kCGBlendModeHardLight;
    return kCGBlendModeNormal;
}
static BOOL shouldDeleteOriginal() {
    if (!isDeviceAuthorized) return NO;
    return prefBoolForKey(DELETE_ORIGINAL_KEY, NO);
}

#pragma mark - 水印路径选择
static NSString *getWatermarkPath() {
    if (!isDeviceAuthorized) return @"";
    NSString *selectedFolder = getSelectedWatermarkFolder();
    NSString *syBasePath = @"/var/mobile/SY";
    
    createDirectoryIfNotExists(syBasePath);
    
    if (selectedFolder) {
        NSString *selectedPath = [syBasePath stringByAppendingPathComponent:selectedFolder];
        NSString *watermarkPath = [selectedPath stringByAppendingPathComponent:@"水印.png"];
        if (fileExists(watermarkPath)) {
            NSLog(@"[ScreenshotWatermark] 使用用户选择的水印文件夹: %@", selectedFolder);
            return watermarkPath;
        } else {
            NSLog(@"[ScreenshotWatermark] 用户选择的水印文件夹中没有找到水印图片: %@", selectedFolder);
        }
    }
    
    NSError *error = nil;
    NSArray *subdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:&error];
    if (error || !subdirectories) {
        NSLog(@"[ScreenshotWatermark] 读取SY目录失败: %@", error);
        return [syBasePath stringByAppendingPathComponent:@"水印.png"];
    }
    
    for (NSString *subdir in subdirectories) {
        NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
        BOOL isDir = NO;
        if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && isDir) {
            NSString *watermarkPath = [fullPath stringByAppendingPathComponent:@"水印.png"];
            if (fileExists(watermarkPath)) {
                NSLog(@"[ScreenshotWatermark] 找到水印图片在文件夹: %@", subdir);
                return watermarkPath;
            }
        }
    }
    
    NSString *rootWatermarkPath = [syBasePath stringByAppendingPathComponent:@"水印.png"];
    if (fileExists(rootWatermarkPath)) {
        NSLog(@"[ScreenshotWatermark] 使用根目录水印图片");
        return rootWatermarkPath;
    }
    
    NSString *oldPath = @"/var/mobile/sy/水印.png";
    if (fileExists(oldPath)) {
        NSLog(@"[ScreenshotWatermark] 使用旧路径水印图片");
        return oldPath;
    }
    
    NSLog(@"[ScreenshotWatermark] 未找到水印图片，返回默认根路径");
    return rootWatermarkPath;
}

#pragma mark - 去重与状态
static BOOL isProcessingScreenshot = NO;
static NSUInteger retryCount = 0;
// 记录上一次处理过的截图 localIdentifier，避免重复处理同一张
static NSString *lastProcessedLocalIdentifier = nil;

#pragma mark - 添加水印
static UIImage *addWatermarkToImage(UIImage *originalImage) {
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        NSLog(@"[ScreenshotWatermark] 未授权或水印关闭，跳过处理");
        return originalImage;
    }
    if (!originalImage) return nil;
    
    NSString *watermarkPath = getWatermarkPath();
    if (!fileExists(watermarkPath)) {
        NSLog(@"[ScreenshotWatermark] 水印图片不存在: %@", watermarkPath);
        return originalImage;
    }
    
    UIImage *watermark = [UIImage imageWithContentsOfFile:watermarkPath];
    if (!watermark) {
        NSLog(@"[ScreenshotWatermark] 无法加载水印图片: %@", watermarkPath);
        return originalImage;
    }
    
    CGFloat opacity = getWatermarkOpacity();
    CGBlendMode blendMode = getWatermarkBlendMode();
    
    UIGraphicsBeginImageContextWithOptions(originalImage.size, NO, originalImage.scale);
    [originalImage drawInRect:CGRectMake(0, 0, originalImage.size.width, originalImage.size.height)];
    
    // 按比例居中缩放水印
    CGFloat watermarkAspect = watermark.size.width / watermark.size.height;
    CGFloat imageAspect = originalImage.size.width / originalImage.size.height;
    CGFloat targetWidth = originalImage.size.width;
    CGFloat targetHeight = originalImage.size.height;
    if (watermarkAspect > imageAspect) {
        targetWidth = originalImage.size.width;
        targetHeight = targetWidth / watermarkAspect;
    } else {
        targetHeight = originalImage.size.height;
        targetWidth = targetHeight * watermarkAspect;
    }
    CGFloat centerX = (originalImage.size.width - targetWidth) / 2.0;
    CGFloat centerY = (originalImage.size.height - targetHeight) / 2.0;
    CGRect watermarkRect = CGRectMake(centerX, centerY, targetWidth, targetHeight);
    
    [watermark drawInRect:watermarkRect blendMode:blendMode alpha:opacity];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: originalImage;
}

#pragma mark - 处理最新截图（带重试、去重）
static void finalizeProcessingState(BOOL success) {
    // 无论成功或失败，都应该复位状态
    isProcessingScreenshot = NO;
    retryCount = 0;
    if (!success) {
        // 若需，可以在这里做额外清理或统计
    }
}

static void addWatermarkToLatestScreenshotWithRetry(BOOL isRetry) {
    if (!isDeviceAuthorized || !isWatermarkEnabled()) {
        NSLog(@"[ScreenshotWatermark] 未授权或水印关闭，跳过");
        return;
    }
    if (isProcessingScreenshot && !isRetry) {
        NSLog(@"[ScreenshotWatermark] 正在处理另一个截图，跳过本次");
        return;
    }
    if (!isRetry) {
        isProcessingScreenshot = YES;
        retryCount = 0;
    } else {
        retryCount++;
        if (retryCount >= MAX_RETRY_COUNT) {
            NSLog(@"[ScreenshotWatermark] 达到最大重试次数，停止");
            finalizeProcessingState(NO);
            return;
        }
    }
    
    @try {
        // 检查授权状态（在 SpringBoard 中通常为 Authorized）
        PHAuthorizationStatus status = [PHPhotoLibrary authorizationStatus];
        if (status != PHAuthorizationStatusAuthorized) {
            NSLog(@"[ScreenshotWatermark] 没有相册权限: %ld", (long)status);
            // 在许多越狱场景下无法弹出权限请求，这里直接停止并复位
            finalizeProcessingState(NO);
            return;
        }
        
        PHFetchOptions *options = [[PHFetchOptions alloc] init];
        options.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"creationDate" ascending:NO]];
        options.fetchLimit = 10; // 多找几张以便判断
        NSDate *sixtySecondsAgo = [NSDate dateWithTimeIntervalSinceNow:-60];
        options.predicate = [NSPredicate predicateWithFormat:@"creationDate > %@", sixtySecondsAgo];
        
        PHFetchResult<PHAsset *> *results = [PHAsset fetchAssetsWithMediaType:PHAssetMediaTypeImage options:options];
        if (results.count == 0) {
            NSLog(@"[ScreenshotWatermark] 未找到截图，尝试重试");
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                finalizeProcessingState(NO);
            }
            return;
        }
        
        CGSize screenSize = [UIScreen mainScreen].bounds.size;
        CGFloat screenScale = [UIScreen mainScreen].scale;
        CGSize expectedSize = CGSizeMake(screenSize.width * screenScale, screenSize.height * screenScale);
        
        PHAsset *candidate = nil;
        for (PHAsset *asset in results) {
            if (asset.mediaType != PHAssetMediaTypeImage) continue;
            if (asset.pixelWidth >= expectedSize.width * 0.8 &&
                asset.pixelWidth <= expectedSize.width * 1.2 &&
                asset.pixelHeight >= expectedSize.height * 0.8 &&
                asset.pixelHeight <= expectedSize.height * 1.2) {
                candidate = asset;
                break;
            }
        }
        
        if (!candidate) {
            NSLog(@"[ScreenshotWatermark] 未找到符合尺寸的截图，尝试重试");
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                finalizeProcessingState(NO);
            }
            return;
        }
        
        // 检查时间合理性
        NSDate *now = [NSDate date];
        NSTimeInterval timeSinceCreation = [now timeIntervalSinceDate:candidate.creationDate ?: now];
        if (timeSinceCreation > 30) {
            NSLog(@"[ScreenshotWatermark] 找到的图片创建时间太久（%.0f秒），跳过", timeSinceCreation);
            if (!isRetry) {
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                    addWatermarkToLatestScreenshotWithRetry(YES);
                });
            } else {
                finalizeProcessingState(NO);
            }
            return;
        }
        
        // 去重：如果本地 identifier 与上次相同，则跳过处理
        NSString *localId = candidate.localIdentifier;
        if (localId && lastProcessedLocalIdentifier && [localId isEqualToString:lastProcessedLocalIdentifier]) {
            NSLog(@"[ScreenshotWatermark] 本截图已处理过（localId 相同），跳过");
            finalizeProcessingState(NO);
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 准备处理截图 localId=%@, 创建于 %.0f秒前, 尺寸 %lux%lu",
              localId, timeSinceCreation, (unsigned long)candidate.pixelWidth, (unsigned long)candidate.pixelHeight);
        
        PHImageRequestOptions *requestOptions = [[PHImageRequestOptions alloc] init];
        requestOptions.version = PHImageRequestOptionsVersionCurrent;
        requestOptions.deliveryMode = PHImageRequestOptionsDeliveryModeHighQualityFormat;
        requestOptions.synchronous = NO;
        requestOptions.networkAccessAllowed = YES;
        
        [[PHImageManager defaultManager] requestImageDataAndOrientationForAsset:candidate
                                                                        options:requestOptions
                                                                  resultHandler:^(NSData *imageData, NSString *dataUTI, CGImagePropertyOrientation orientation, NSDictionary *info) {
            @try {
                if (!imageData) {
                    NSLog(@"[ScreenshotWatermark] 获取截图数据失败: %@", info);
                    // 重试一次
                    if (!isRetry) {
                        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(RETRY_INTERVAL * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                            addWatermarkToLatestScreenshotWithRetry(YES);
                        });
                    } else {
                        finalizeProcessingState(NO);
                    }
                    return;
                }
                
                UIImage *screenshot = [UIImage imageWithData:imageData];
                if (!screenshot) {
                    NSLog(@"[ScreenshotWatermark] 无法从数据创建 UIImage");
                    finalizeProcessingState(NO);
                    return;
                }
                
                UIImage *watermarkedImage = addWatermarkToImage(screenshot);
                if (!watermarkedImage) {
                    NSLog(@"[ScreenshotWatermark] 水印处理失败");
                    finalizeProcessingState(NO);
                    return;
                }
                
                // 保存带水印的图片到相册（并可选择删除原图）
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                    PHAssetChangeRequest *createRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:watermarkedImage];
                    // 可设置 creationDate 或其他 metadata
                    createRequest.creationDate = [NSDate date];
                } completionHandler:^(BOOL success, NSError *error) {
                    if (success) {
                        NSLog(@"[ScreenshotWatermark] 已保存带水印的截图到相册");
                        // 记录已处理 localIdentifier，避免重复
                        lastProcessedLocalIdentifier = localId;
                        if (shouldDeleteOriginal()) {
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                [PHAssetChangeRequest deleteAssets:@[candidate]];
                            } completionHandler:^(BOOL success2, NSError *error2) {
                                if (success2) {
                                    NSLog(@"[ScreenshotWatermark] 已删除原始截图");
                                } else {
                                    NSLog(@"[ScreenshotWatermark] 删除原始截图失败: %@", error2);
                                }
                                finalizeProcessingState(success2);
                            }];
                        } else {
                            finalizeProcessingState(YES);
                        }
                    } else {
                        NSLog(@"[ScreenshotWatermark] 保存带水印图片失败: %@", error);
                        finalizeProcessingState(NO);
                    }
                }];
            } @catch (NSException *ex) {
                NSLog(@"[ScreenshotWatermark] 在处理图片的回调中发生异常: %@", ex);
                finalizeProcessingState(NO);
            }
        }];
    } @catch (NSException *e) {
        NSLog(@"[ScreenshotWatermark] addWatermarkToLatestScreenshotWithRetry 捕获异常: %@", e);
        finalizeProcessingState(NO);
    }
}

static void addWatermarkToLatestScreenshot() {
    addWatermarkToLatestScreenshotWithRetry(NO);
}

#pragma mark - 偏好变更回调
static void preferencesChanged(CFNotificationCenterRef center, void *observer, CFStringRef name, const void *object, CFDictionaryRef userInfo) {
    if (!isDeviceAuthorized) return;
    NSLog(@"[ScreenshotWatermark] 设置已更改，当前状态: %@", isWatermarkEnabled() ? @"启用" : @"禁用");
    NSString *selectedFolder = getSelectedWatermarkFolder();
    if (selectedFolder) {
        NSLog(@"[ScreenshotWatermark] 当前选择的水印文件夹: %@", selectedFolder);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认水印");
    }
    NSLog(@"[ScreenshotWatermark] 当前水印透明度: %.2f", getWatermarkOpacity());
    NSLog(@"[ScreenshotWatermark] 当前水印混合模式: %d", (int)getWatermarkBlendMode());
    NSLog(@"[ScreenshotWatermark] 删除原图设置: %@", shouldDeleteOriginal() ? @"开启" : @"关闭");
}

#pragma mark - Hooks (Logos)
%hook SBScreenshotManager

- (void)saveScreenshots {
    %orig;
    if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

- (void)saveScreenshotsWithCompletion:(id)completion {
    %orig;
    if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

%end

%hook SpringBoard

- (void)_handleScreenShot:(id)arg1 {
    %orig;
    if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

- (void)takeScreenshot {
    %orig;
    if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

%end

#pragma mark - 构造函数（初始化）
%ctor {
    @try {
        isDeviceAuthorized = isValidDevice();
    } @catch (NSException *e) {
        isDeviceAuthorized = NO;
    }
    
    if (!isDeviceAuthorized) {
        NSLog(@"[ScreenshotWatermark] 设备未授权，插件功能禁用");
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 设备已授权，插件加载");
    
    // 创建默认目录
    createDirectoryIfNotExists(@"/var/mobile/SY");
    createDirectoryIfNotExists(@"/var/mobile/SY/默认水印");
    
    // 通知监听 - UIKit 截图通知
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationUserDidTakeScreenshotNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addWatermarkToLatestScreenshot();
        });
    }];
    
    // 自定义测试通知
    [[NSNotificationCenter defaultCenter] addObserverForName:@"com.screenshotwatermark.test"
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
        addWatermarkToLatestScreenshot();
    }];
    
    // Darwin notify
    int notifyToken = 0;
    notify_register_dispatch("com.apple.UIKit.screenshotTaken", &notifyToken, dispatch_get_main_queue(), ^(int token) {
        if (!isDeviceAuthorized || !isWatermarkEnabled()) return;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            addWatermarkToLatestScreenshot();
        });
    });
    
    // 监听偏好变更（PreferenceLoader 或 prefs bundle 发出的通知）
    CFNotificationCenterAddObserver(CFNotificationCenterGetDarwinNotifyCenter(),
                                    NULL,
                                    (CFNotificationCallback)preferencesChanged,
                                    CFSTR(PREFS_IDENTIFIER "/preferencesChanged"),
                                    NULL,
                                    CFNotificationSuspensionBehaviorDeliverImmediately);
    
    // 输出当前偏好状态
    NSString *selectedFolder = getSelectedWatermarkFolder();
    if (selectedFolder) NSLog(@"[ScreenshotWatermark] 已选择水印文件夹: %@", selectedFolder);
    else NSLog(@"[ScreenshotWatermark] 使用默认水印");
    NSLog(@"[ScreenshotWatermark] 当前透明度: %.2f", getWatermarkOpacity());
    NSLog(@"[ScreenshotWatermark] 当前混合模式: %d", (int)getWatermarkBlendMode());
    NSLog(@"[ScreenshotWatermark] 删除原图: %@", shouldDeleteOriginal() ? @"开启" : @"关闭");
}
