#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>
#import "SWPRootListController.h"

// 水印文件夹选择器界面
@interface WatermarkFolderSelector : UITableViewController
@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, copy) void (^completionHandler)(NSString *selectedFolder);
+ (void)presentFromViewController:(UIViewController *)parentController completion:(void (^)(NSString *))completion;
@end

@implementation WatermarkFolderSelector

+ (void)presentFromViewController:(UIViewController *)parentController completion:(void (^)(NSString *))completion {
    WatermarkFolderSelector *selector = [[WatermarkFolderSelector alloc] init];
    selector.completionHandler = completion;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selector];
    [parentController presentViewController:navController animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"选择水印文件夹";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    
    // 获取所有可用文件夹
    [self loadAvailableFolders];
}

- (void)loadAvailableFolders {
    NSMutableArray *availableFolders = [NSMutableArray array];
    NSString *syBasePath = @"/var/mobile/SY";
    
    // 添加默认选项
    [availableFolders addObject:@"默认水印"];
    
    // 检查SY目录是否存在
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:syBasePath isDirectory:&isDir] && isDir) {
        NSError *error;
        NSArray *subdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:&error];
        
        if (!error) {
            for (NSString *subdir in subdirectories) {
                NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
                NSString *watermarkPath = [fullPath stringByAppendingPathComponent:@"水印.png"];
                
                // 只显示包含水印图片的文件夹
                if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && 
                    isDir && 
                    [[NSFileManager defaultManager] fileExistsAtPath:watermarkPath]) {
                    [availableFolders addObject:subdir];
                }
            }
        } else {
            NSLog(@"[ScreenshotWatermark] 读取SY目录失败: %@", error);
        }
    }
    
    self.folders = availableFolders;
    [self.tableView reloadData];
}

- (void)cancel {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.folders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell"];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"Cell"];
    }
    
    NSString *folder = self.folders[indexPath.row];
    cell.textLabel.text = folder;
    
    // 标记当前选中的文件夹
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist"];
    NSString *selectedFolder = [prefs objectForKey:@"watermarkFolder"];
    
    if ((indexPath.row == 0 && (!selectedFolder || [selectedFolder isEqualToString:@"默认水印"])) || 
        [folder isEqualToString:selectedFolder]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    } else {
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *selectedFolder = self.folders[indexPath.row];
    
    // 保存选择
    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist"]];
    
    if (indexPath.row == 0) {
        [prefs removeObjectForKey:@"watermarkFolder"];
    } else {
        [prefs setObject:selectedFolder forKey:@"watermarkFolder"];
    }
    
    [prefs writeToFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist" atomically:YES];
    
    // 通知设置更改
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                        CFSTR("com.screenshotwatermark.preferences/preferencesChanged"), 
                                        NULL, NULL, YES);
    
    if (self.completionHandler) {
        self.completionHandler(selectedFolder);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation SWPRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        // 加载设置面板布局配置文件
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
        
        // 动态更新水印文件夹列表
        [self updateWatermarkFolders];
    }
    return _specifiers;
}

- (void)updateWatermarkFolders {
    // 查找可用的水印文件夹
    NSMutableArray *folders = [NSMutableArray arrayWithObject:@"默认水印"];
    NSMutableArray *folderValues = [NSMutableArray arrayWithObject:@"默认水印"];
    
    NSString *syBasePath = @"/var/mobile/SY";
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSError *error = nil;
    NSArray *subdirectories = [fileManager contentsOfDirectoryAtPath:syBasePath error:&error];
    
    if (!error) {
        for (NSString *subdir in subdirectories) {
            NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
            NSString *watermarkPath = [fullPath stringByAppendingPathComponent:@"水印.png"];
            
            BOOL isDirectory;
            if ([fileManager fileExistsAtPath:fullPath isDirectory:&isDirectory] && 
                isDirectory && 
                [fileManager fileExistsAtPath:watermarkPath]) {
                [folders addObject:subdir];
                [folderValues addObject:subdir];
            }
        }
    }
    
    // 更新水印文件夹选择器
    PSSpecifier *watermarkSpecifier = [self specifierForID:@"watermarkFolder"];
    if (watermarkSpecifier) {
        [watermarkSpecifier setProperty:folders forKey:@"validTitles"];
        [watermarkSpecifier setProperty:folderValues forKey:@"validValues"];
        
        // 重新加载设置项
        [self reloadSpecifier:watermarkSpecifier];
    }
}

- (id)readPreferenceValue:(PSSpecifier*)specifier {
    // 读取路径与 RootList.plist 中 "defaults" 键一致：com.screenshotwatermark.preferences
    NSString *prefsPath = @"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist";
    NSDictionary *settings = [NSDictionary dictionaryWithContentsOfFile:prefsPath];
    
    // 若对应键值不存在，返回配置中设置的默认值
    if (!settings[specifier.properties[@"key"]]) {
        return specifier.properties[@"default"];
    }
    return settings[specifier.properties[@"key"]];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier*)specifier {
    // 写入路径与读取路径保持一致，确保设置值能正确保存
    NSString *prefsPath = @"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist";
    NSMutableDictionary *defaults = [NSMutableDictionary dictionary];
    
    // 先读取已有设置（避免覆盖其他配置项）
    [defaults addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:prefsPath] ?: @{}];
    // 更新当前设置项的值
    [defaults setObject:value forKey:specifier.properties[@"key"]];
    // 写入文件保存
    [defaults writeToFile:prefsPath atomically:YES];

    // 若配置了通知名，触发 Darwin 通知（供插件功能代码监听设置变化）
    CFStringRef notificationName = (__bridge CFStringRef)specifier.properties[@"PostNotification"];
    if (notificationName) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), notificationName, NULL, NULL, YES);
    }
    
    // 如果是水印文件夹设置项，立即更新显示
    if ([specifier.identifier isEqualToString:@"watermarkFolder"]) {
        [self updateSelectedFolderDisplay:value];
    }
}

// 当视图出现时刷新文件夹列表
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateWatermarkFolders];
    
    // 更新当前选中的文件夹显示
    NSString *selectedFolder = [self getCurrentSelectedFolderName];
    [self updateSelectedFolderDisplay:selectedFolder];
}

// 处理设置项点击
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    // 获取点击的单元格
    PSTableCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    
    // 检查是否是水印文件夹设置项
    if ([cell.specifier.identifier isEqualToString:@"watermarkFolder"]) {
        // 直接弹出文件夹选择器，不调用super
        [WatermarkFolderSelector presentFromViewController:self completion:^(NSString *selectedFolder) {
            // 更新界面显示
            [self updateSelectedFolderDisplay:selectedFolder];
            
            // 保存选择
            NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
            [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist"]];
            
            if ([selectedFolder isEqualToString:@"默认水印"]) {
                [prefs removeObjectForKey:@"watermarkFolder"];
            } else {
                [prefs setObject:selectedFolder forKey:@"watermarkFolder"];
            }
            
            [prefs writeToFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist" atomically:YES];
            
            // 通知设置更改
            CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                                CFSTR("com.screenshotwatermark.preferences/preferencesChanged"), 
                                                NULL, NULL, YES);
        }];
    } else {
        // 对于其他设置项，调用默认行为
        [super tableView:tableView didSelectRowAtIndexPath:indexPath];
    }
}

// 更新选中的文件夹显示
- (void)updateSelectedFolderDisplay:(NSString *)selectedFolder {
    // 获取当前选中的文件夹名称
    NSString *displayName = selectedFolder ? selectedFolder : @"默认水印";
    
    // 查找水印文件夹设置项
    PSSpecifier *watermarkSpecifier = [self specifierForID:@"watermarkFolder"];
    if (watermarkSpecifier) {
        // 更新设置项的显示值
        [watermarkSpecifier setProperty:displayName forKey:@"value"];
        
        // 重新加载设置项
        [self reloadSpecifier:watermarkSpecifier];
        
        // 强制刷新表格
        [self.table reloadData];
    }
}

// 获取当前选中的文件夹名称
- (NSString *)getCurrentSelectedFolderName {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/com.screenshotwatermark.preferences.plist"];
    NSString *selectedFolder = [prefs objectForKey:@"watermarkFolder"];
    
    if (!selectedFolder || [selectedFolder isEqualToString:@"默认水印"] || [selectedFolder isEqualToString:@""]) {
        return @"默认水印";
    }
    
    return selectedFolder;
}

@end