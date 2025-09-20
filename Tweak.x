#import <UIKit/UIKit.h>
#import <Photos/Photos.h>
#import <SpringBoard/SpringBoard.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import <notify.h>
#import <dlfcn.h>
#import <sys/sysctl.h>
#import <CoreImage/CoreImage.h>

// 设置标识符
#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define ENABLED_KEY "enabled"
#define WATERMARK_FOLDER_KEY "watermarkFolder"
#define WATERMARK_OPACITY_KEY "watermarkOpacity"
#define WATERMARK_BLEND_MODE_KEY "watermarkBlendMode"
#define DELETE_ORIGINAL_KEY "deleteOriginal"
#define FRAME_ENABLED_KEY "frameEnabled"
#define FRAME_FOLDER_KEY "frameFolder"

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
            @"MDAwMDgxMjAtMDAxQzU0OEEzNkEwQzAxRQ==", // Base64编码的UDID 1
            @"MDAwMDgxMjAtMDAxRTY0RDgzRUEwQzAxRQ==",
            @"MDAwMDgxMjAtMDAwNDM0QzExRTk4MjAxRQ==",

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

@"MDAwMDgwMzAtMDAxQTE5MDAxNDYxODAyRQ==",

@"MDAwMDgxMTAtMDAxODBEOEExRTgwNDAxRQ==",

@"MDAwMDgxMjAtMDAxNjQ5MjIxQTk4MjAxRQ==",

@"MDAwMDgxMjAtMDAwNjQwQUMyMjEwMjAxRQ==",

@"MDAwMDgxMTAtMDAwODc5MkUzQzgzODAxRQ==",

@"MDAwMDgxMTAtMDAxQzIwOUUyRUJBODAxRQ==",

@"MDAwMDgxMjAtMDAwNjc4RDkwQTgwQzAxRQ==",

@"MDAwMDgxMTAtMDAxQzIwOUUyRUJBODAxRQ==",

@"MDAwMDgxMjAtMDAxRTJDQTIzNkRCNDAxRQ==",

@"MDAwMDgxMjAtMDAxMjI0MTgwMURCNDAxRQ==",

@"MDAwMDgxMjAtMDAwNjY0NTIxRTBCQzAxRQ==",

@"MDAwMDgxMTAtMDAxMjI1Q0UxMUUxODAxRQ==",

@"MDAwMDgxMjAtMDAxNjM1QzgzQTgwMjAxRQ==",

@"MDAwMDgxMTAtMDAxQzUxOTgwQTkxNDAxRQ==",

@"MDAwMDgxMDEtMDAxQzRDMkMzQTgyMDAxRQ==",

@"MDAwMDgxMjAtMDAxNjc4ODYwQzdCQzAxRQ==",

@"MDAwMDgxMjAtMDAxQTY0QUEzQ0ZCQzAxRQ==",

@"MDAwMDgxMjAtMDAwMDY1ODkyRTY4QzAxRQ==",

@"MDAwMDgxMDEtMDAxRTUxNTkzRTdBMDAxRQ==",

@"MDAwMDgxMjAtMDAxODA4MzQyRUUwMjAxRQ==",
 
@"MDAwMDgxMTAtMDAxNDA1MzgzQTMzODAxRQ==",

@"MDAwMDgxMjAtMDAxNDE4OTgzQzk4MjAxRQ==",

@"MDAwMDgxMjAtMDAwMTBEMkMwQUYzQzAxRQ==",

@"MDAwMDgxMjAtMDAxQzVDMkEwQzQ0QzAxRQ==",

@"MDAwMDgxMjAtMDAwMjMxNTYzQTdCQzAxRQ==",

@"MDAwMDgxMjAtMDAxQzU4NUEyMjQ0MjAxRQ==",

@"MDAwMDgxMTAtMDAwQzZDRDAzNDkyODAxRQ==",

@"MDAwMDgxMjAtMDAxMDE1NDgwMjQwQzAxRQ==",

@"MDAwMDgxMjAtMDAxMDM5MkEwRTUwQzAxRQ==",

@"MDAwMDgxMjAtMDAwMjFDMzEzRTYzQzAxRQ==",
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

// 获取套壳功能设置状态
static BOOL isFrameEnabled() {
    // 只有设备已授权时才检查设置
    if (!isDeviceAuthorized) return NO;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    return prefs ? [[prefs objectForKey:@FRAME_ENABLED_KEY] boolValue] : YES;
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

// 获取用户选择的套壳模板文件夹
static NSString *getSelectedFrameFolder() {
    // 只有设备已授权时才获取设置
    if (!isDeviceAuthorized) return nil;
    
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *folder = [prefs objectForKey:@FRAME_FOLDER_KEY];
    
    if (!folder || [folder isEqualToString:@"默认套壳"] || [folder isEqualToString:@""]) {
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

// 获取套壳图片路径
static NSString *getFramePath() {
    // 只有设备已授权时才获取套壳路径
    if (!isDeviceAuthorized) return @"";
    
    NSString *selectedFolder = getSelectedFrameFolder();
    NSString *syBasePath = @"/var/mobile/SY";
    
    // 首先检查选择的套壳模板文件夹中是否有tk.png
    if (selectedFolder) {
        NSString *selectedPath = [syBasePath stringByAppendingPathComponent:selectedFolder];
        NSString *framePath = [selectedPath stringByAppendingPathComponent:@"tk.png"];
        if (fileExists(framePath)) {
            NSLog(@"[ScreenshotWatermark] 使用用户选择的套壳模板文件夹: %@", selectedFolder);
            return framePath;
        }
    }
    
    // 然后检查所有子文件夹
    NSError *error = nil;
    NSArray *subdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:&error];
    
    if (!error) {
        for (NSString *subdir in subdirectories) {
            NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
            NSString *framePath = [fullPath stringByAppendingPathComponent:@"tk.png"];
            
            BOOL isDirectory;
            if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDirectory] && 
                isDirectory && 
                fileExists(framePath)) {
                NSLog(@"[ScreenshotWatermark] 找到套壳图片在文件夹: %@", subdir);
                return framePath;
            }
        }
    }
    
    // 最后检查根目录
    NSString *rootFramePath = [syBasePath stringByAppendingPathComponent:@"tk.png"];
    if (fileExists(rootFramePath)) {
        NSLog(@"[ScreenshotWatermark] 使用根目录套壳图片");
        return rootFramePath;
    }
    
    NSString *oldPath = @"/var/mobile/sy/tk.png";
    if (fileExists(oldPath)) {
        NSLog(@"[ScreenshotWatermark] 使用旧路径套壳图片");
        return oldPath;
    }
    
    NSLog(@"[ScreenshotWatermark] 未找到套壳图片");
    return @"";
}

// 获取套壳配置文件路径
static NSString *getFrameConfigPath() {
    NSString *framePath = getFramePath();
    if ([framePath isEqualToString:@""]) {
        return @"";
    }
    
    // 将tk.png替换为tk.cfg
    NSString *configPath = [[framePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"tk.cfg"];
    
    if (fileExists(configPath)) {
        NSLog(@"[ScreenshotWatermark] 找到套壳配置文件: %@", configPath);
        return configPath;
    }
    
    // 如果没有找到tk.cfg，尝试查找其他可能的配置文件名称
    NSArray *possibleConfigNames = @[@"frame.cfg", @"config.cfg", @"settings.cfg"];
    for (NSString *name in possibleConfigNames) {
        NSString *altConfigPath = [[framePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:name];
        if (fileExists(altConfigPath)) {
            NSLog(@"[ScreenshotWatermark] 找到替代配置文件: %@", altConfigPath);
            return altConfigPath;
        }
    }
    
    NSLog(@"[ScreenshotWatermark] 未找到套壳配置文件");
    return @"";
}

// 解析套壳配置文件
static NSDictionary *parseFrameConfig(NSString *configPath, CGSize frameSize) {
    if ([configPath isEqualToString:@""]) {
        return nil;
    }
    
    NSError *error = nil;
    NSString *configContent = [NSString stringWithContentsOfFile:configPath encoding:NSUTF8StringEncoding error:&error];
    
    if (error || !configContent) {
        NSLog(@"[ScreenshotWatermark] 读取配置文件失败: %@", error);
        return nil;
    }
    
    // 尝试解析JSON格式
    NSData *jsonData = [configContent dataUsingEncoding:NSUTF8StringEncoding];
    NSDictionary *configDict = [NSJSONSerialization JSONObjectWithData:jsonData options:0 error:&error];
    
    if (!error && configDict) {
        NSLog(@"[ScreenshotWatermark] 解析JSON配置文件成功: %@", configDict);
        
        // 如果配置中指定了设计尺寸，计算缩放比例
        if (configDict[@"template_width"] && configDict[@"template_height"]) {
            CGFloat designWidth = [configDict[@"template_width"] floatValue];
            CGFloat designHeight = [configDict[@"template_height"] floatValue];
            
            if (designWidth > 0 && designHeight > 0) {
                CGFloat scaleX = frameSize.width / designWidth;
                CGFloat scaleY = frameSize.height / designHeight;
                
                NSLog(@"[ScreenshotWatermark] 设计尺寸: %.0fx%.0f, 实际尺寸: %.0fx%.0f, 缩放比例: x=%.3f, y=%.3f", 
                      designWidth, designHeight, frameSize.width, frameSize.height, scaleX, scaleY);
                
                // 创建缩放后的配置字典
                NSMutableDictionary *scaledConfig = [NSMutableDictionary dictionaryWithDictionary:configDict];
                
                // 缩放所有坐标参数
                NSArray *coordinateKeys = @[@"left_top_x", @"left_top_y", 
                                           @"right_top_x", @"right_top_y",
                                           @"left_bottom_x", @"left_bottom_y",
                                           @"right_bottom_x", @"right_bottom_y",
                                           @"x", @"y", @"width", @"height"];
                
                for (NSString *key in coordinateKeys) {
                    if (configDict[key]) {
                        CGFloat value = [configDict[key] floatValue];
                        // 根据坐标类型选择缩放轴
                        if ([key hasSuffix:@"_x"] || [key isEqualToString:@"x"] || [key isEqualToString:@"width"]) {
                            value *= scaleX;
                        } else if ([key hasSuffix:@"_y"] || [key isEqualToString:@"y"] || [key isEqualToString:@"height"]) {
                            value *= scaleY;
                        }
                        scaledConfig[key] = @(value);
                    }
                }
                
                NSLog(@"[ScreenshotWatermark] 缩放后的配置: %@", scaledConfig);
                return [scaledConfig copy];
            }
        }
        
        return configDict;
    }
    
    // 如果不是JSON格式，尝试解析键值对格式
    NSMutableDictionary *keyValueDict = [NSMutableDictionary dictionary];
    NSArray *lines = [configContent componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    
    for (NSString *line in lines) {
        // 忽略空行和注释行
        if ([line length] == 0 || [line hasPrefix:@"#"] || [line hasPrefix:@"//"]) {
            continue;
        }
        
        // 尝试解析JSON行
        if ([line hasPrefix:@"{"] && [line hasSuffix:@"}"]) {
            NSData *lineData = [line dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *lineDict = [NSJSONSerialization JSONObjectWithData:lineData options:0 error:&error];
            
            if (!error && lineDict) {
                [keyValueDict addEntriesFromDictionary:lineDict];
                continue;
            }
        }
        
        // 解析键值对
        NSArray *components = [line componentsSeparatedByString:@"="];
        if ([components count] == 2) {
            NSString *key = [components[0] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            NSString *value = [components[1] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
            
            if ([key length] > 0 && [value length] > 0) {
                // 移除可能的引号
                value = [value stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\"'"]];
                [keyValueDict setObject:value forKey:key];
            }
        }
    }
    
    NSLog(@"[ScreenshotWatermark] 解析配置文件结果: %@", keyValueDict);
    
    // 如果配置中指定了设计尺寸，计算缩放比例
    if (keyValueDict[@"template_width"] && keyValueDict[@"template_height"]) {
        CGFloat designWidth = [keyValueDict[@"template_width"] floatValue];
        CGFloat designHeight = [keyValueDict[@"template_height"] floatValue];
        
        if (designWidth > 0 && designHeight > 0) {
            CGFloat scaleX = frameSize.width / designWidth;
            CGFloat scaleY = frameSize.height / designHeight;
            
            NSLog(@"[ScreenshotWatermark] 设计尺寸: %.0fx%.0f, 实际尺寸: %.0fx%.0f, 缩放比例: x=%.3f, y=%.3f", 
                  designWidth, designHeight, frameSize.width, frameSize.height, scaleX, scaleY);
            
            // 缩放所有坐标参数
            NSArray *coordinateKeys = @[@"left_top_x", @"left_top_y", 
                                       @"right_top_x", @"right_top_y",
                                       @"left_bottom_x", @"left_bottom_y",
                                       @"right_bottom_x", @"right_bottom_y",
                                       @"x", @"y", @"width", @"height"];
            
            for (NSString *key in coordinateKeys) {
                if (keyValueDict[key]) {
                    CGFloat value = [keyValueDict[key] floatValue];
                    // 根据坐标类型选择缩放轴
                    if ([key hasSuffix:@"_x"] || [key isEqualToString:@"x"] || [key isEqualToString:@"width"]) {
                        value *= scaleX;
                    } else if ([key hasSuffix:@"_y"] || [key isEqualToString:@"y"] || [key isEqualToString:@"height"]) {
                        value *= scaleY;
                    }
                    keyValueDict[key] = [NSString stringWithFormat:@"%.0f", value];
                }
            }
            
            NSLog(@"[ScreenshotWatermark] 缩放后的配置: %@", keyValueDict);
        }
    }
    
    return [keyValueDict copy];
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

// 使用Core Image进行透视变换
static UIImage *applyPerspectiveTransform(UIImage *originalImage, NSDictionary *config, CGSize frameSize) {
    NSLog(@"[ScreenshotWatermark] 应用透视变换");
    
    // 获取四个角的坐标
    CGFloat leftTopX = [config[@"left_top_x"] floatValue];
    CGFloat leftTopY = [config[@"left_top_y"] floatValue];
    CGFloat rightTopX = [config[@"right_top_x"] floatValue];
    CGFloat rightTopY = [config[@"right_top_y"] floatValue];
    CGFloat leftBottomX = [config[@"left_bottom_x"] floatValue];
    CGFloat leftBottomY = [config[@"left_bottom_y"] floatValue];
    CGFloat rightBottomX = [config[@"right_bottom_x"] floatValue];
    CGFloat rightBottomY = [config[@"right_bottom_y"] floatValue];
    
    // 创建CIImage
    CIImage *inputImage = [[CIImage alloc] initWithImage:originalImage];
    
    // 创建透视变换滤镜
    CIFilter *filter = [CIFilter filterWithName:@"CIPerspectiveTransform"];
    [filter setValue:inputImage forKey:kCIInputImageKey];
    
    // 设置四个角的坐标
    [filter setValue:[CIVector vectorWithX:leftTopX Y:frameSize.height - leftTopY] forKey:@"inputTopLeft"];
    [filter setValue:[CIVector vectorWithX:rightTopX Y:frameSize.height - rightTopY] forKey:@"inputTopRight"];
    [filter setValue:[CIVector vectorWithX:rightBottomX Y:frameSize.height - rightBottomY] forKey:@"inputBottomRight"];
    [filter setValue:[CIVector vectorWithX:leftBottomX Y:frameSize.height - leftBottomY] forKey:@"inputBottomLeft"];
    
    // 获取输出图像
    CIImage *outputImage = [filter valueForKey:kCIOutputImageKey];
    
    // 创建CIContext
    CIContext *context = [CIContext contextWithOptions:nil];
    
    // 渲染CIImage到CGImage
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:CGRectMake(0, 0, frameSize.width, frameSize.height)];
    
    // 转换为UIImage
    UIImage *transformedImage = [UIImage imageWithCGImage:cgImage];
    
    // 释放CGImage
    CGImageRelease(cgImage);
    
    return transformedImage;
}

// 静态函数：添加套壳到图片
static UIImage *addFrameToImage(UIImage *originalImage) {
    if (!isDeviceAuthorized || !isFrameEnabled()) {
        NSLog(@"[ScreenshotWatermark] 设备未授权或套壳功能已关闭，跳过处理");
        return originalImage;
    }
    
    NSLog(@"[ScreenshotWatermark] 开始添加套壳到图片");
    
    NSString *framePath = getFramePath();
    
    if (!fileExists(framePath)) {
        NSLog(@"[ScreenshotWatermark] 错误: 套壳图片不存在于路径: %@", framePath);
        NSLog(@"[ScreenshotWatermark] 请将套壳图片放置在 /var/mobile/SY/任意文件夹/tk.png");
        return originalImage;
    }
    
    UIImage *frameImage = [UIImage imageWithContentsOfFile:framePath];
    
    if (!frameImage) {
        NSLog(@"[ScreenshotWatermark] 错误: 无法加载套壳图片，即使文件存在");
        return originalImage;
    }
    
    NSLog(@"[ScreenshotWatermark] 成功加载套壳图片，尺寸: %@", NSStringFromCGSize(frameImage.size));
    NSLog(@"[ScreenshotWatermark] 原始图片尺寸: %@", NSStringFromCGSize(originalImage.size));
    
    // 获取配置文件
    NSString *configPath = getFrameConfigPath();
    NSDictionary *config = parseFrameConfig(configPath, frameImage.size);
    
    // 创建与套壳图片相同大小的画布
    UIGraphicsBeginImageContextWithOptions(frameImage.size, NO, frameImage.scale);
    
    // 先绘制原始图片（可能应用透视变换）
    if (config && config[@"left_top_x"] && config[@"left_top_y"] && 
        config[@"right_top_x"] && config[@"right_top_y"] &&
        config[@"left_bottom_x"] && config[@"left_bottom_y"] &&
        config[@"right_bottom_x"] && config[@"right_bottom_y"]) {
        // 使用四点坐标模式，应用透视变换
        UIImage *transformedImage = applyPerspectiveTransform(originalImage, config, frameImage.size);
        [transformedImage drawInRect:CGRectMake(0, 0, frameImage.size.width, frameImage.size.height)];
    } else if (config && config[@"x"] && config[@"y"] && config[@"width"] && config[@"height"]) {
        // 使用简单坐标模式
        CGFloat x = [config[@"x"] floatValue];
        CGFloat y = [config[@"y"] floatValue];
        CGFloat width = [config[@"width"] floatValue];
        CGFloat height = [config[@"height"] floatValue];
        
        // 确保坐标和尺寸在有效范围内
        x = MAX(0, MIN(x, frameImage.size.width));
        y = MAX(0, MIN(y, frameImage.size.height));
        width = MIN(width, frameImage.size.width - x);
        height = MIN(height, frameImage.size.height - y);
        
        [originalImage drawInRect:CGRectMake(x, y, width, height)];
    } else {
        // 默认居中并缩放以适应套壳图片
        CGFloat scale = MIN(frameImage.size.width / originalImage.size.width, 
                           frameImage.size.height / originalImage.size.height);
        CGFloat width = originalImage.size.width * scale;
        CGFloat height = originalImage.size.height * scale;
        CGFloat x = (frameImage.size.width - width) / 2.0;
        CGFloat y = (frameImage.size.height - height) / 2.0;
        
        [originalImage drawInRect:CGRectMake(x, y, width, height)];
    }
    
    // 再绘制套壳图片
    [frameImage drawInRect:CGRectMake(0, 0, frameImage.size.width, frameImage.size.height)];
    
    UIImage *framedImage = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    NSLog(@"[ScreenshotWatermark] 套壳添加完成");
    return framedImage;
}

// 静态函数：处理图片（先加水印，再加套壳）
static UIImage *processImage(UIImage *originalImage) {
    UIImage *processedImage = originalImage;
    
    // 先添加水印
    if (isWatermarkEnabled()) {
        processedImage = addWatermarkToImage(processedImage);
    }
    
    // 再添加套壳
    if (isFrameEnabled()) {
        processedImage = addFrameToImage(processedImage);
    }
    
    return processedImage;
}

// 静态函数：处理最新截图（带重试机制）
static void addWatermarkToLatestScreenshotWithRetry(BOOL isRetry) {
    if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
        NSLog(@"[ScreenshotWatermark] 设备未授权或水印和套壳功能都已关闭，跳过处理");
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
                        UIImage *processedImage = processImage(screenshot);
                        
                        if (processedImage) {
                            BOOL deleteOriginal = shouldDeleteOriginal();
                            
                            [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                                PHAssetChangeRequest *createRequest = [PHAssetChangeRequest creationRequestForAssetFromImage:processedImage];
                                createRequest.creationDate = [NSDate date];
                            } completionHandler:^(BOOL success, NSError *error) {
                                if (success) {
                                    NSLog(@"[ScreenshotWatermark] 已保存处理后的截图到相册");
                                    
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
                            NSLog(@"[ScreenshotWatermark] 错误: 图片处理失败");
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
    NSLog(@"[ScreenshotWatermark] 套壳功能状态: %@", isFrameEnabled() ? @"启用" : @"禁用");
    
    NSString *selectedFolder = getSelectedWatermarkFolder();
    if (selectedFolder) {
        NSLog(@"[ScreenshotWatermark] 当前选择的水印文件夹: %@", selectedFolder);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认水印");
    }
    
    NSString *selectedFrame = getSelectedFrameFolder();
    if (selectedFrame) {
        NSLog(@"[ScreenshotWatermark] 当前选择的套壳模板: %@", selectedFrame);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认套壳");
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
    
    if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
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
    
    if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
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
    
    if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到截图事件 (_handleScreenShot:)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
}

- (void)takeScreenshot {
    %orig;
    
    if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
        return;
    }
    
    NSLog(@"[ScreenshotWatermark] 检测到截图事件 (takeScreenshot)");
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        addWatermarkToLatestScreenshot();
    });
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
        if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
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
        if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
            NSLog(@"[ScreenshotWatermark] 设备未授权或水印和套壳功能都已关闭，跳过手动测试");
            return;
        }
        
        NSLog(@"[ScreenshotWatermark] 手动触发水印添加");
        addWatermarkToLatestScreenshot();
    }];
    
    int token;
    notify_register_dispatch("com.apple.UIKit.screenshotTaken", &token, dispatch_get_main_queue(), ^(int token) {
        if (!isDeviceAuthorized || (!isWatermarkEnabled() && !isFrameEnabled())) {
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
    
    NSString *selectedFrame = getSelectedFrameFolder();
    if (selectedFrame) {
        NSLog(@"[ScreenshotWatermark] 当前选择的套壳模板: %@", selectedFrame);
    } else {
        NSLog(@"[ScreenshotWatermark] 使用默认套壳");
    }
    
    CGFloat opacity = getWatermarkOpacity();
    NSLog(@"[ScreenshotWatermark] 当前水印透明度: %.2f", opacity);
    
    CGBlendMode blendMode = getWatermarkBlendMode();
    NSLog(@"[ScreenshotWatermark] 当前水印混合模式: %d", blendMode);
    
    BOOL deleteOriginal = shouldDeleteOriginal();
    NSLog(@"[ScreenshotWatermark] 删除原图设置: %@", deleteOriginal ? @"开启" : @"关闭");
    
    BOOL frameEnabled = isFrameEnabled();
    NSLog(@"[ScreenshotWatermark] 套壳功能状态: %@", frameEnabled ? @"启用" : @"禁用");
}