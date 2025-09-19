#import "FrameSelectionController.h"
#import <Preferences/Preferences.h>

// 设置标识符
#define PREFS_IDENTIFIER "com.screenshotwatermark.preferences"
#define FRAME_FOLDER_KEY "frameFolder"

@implementation FrameSelectionController

+ (void)presentFromViewController:(UIViewController *)parentController completion:(void (^)(NSString *))completion {
    FrameSelectionController *selector = [[FrameSelectionController alloc] init];
    selector.completionHandler = completion;
    
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:selector];
    [parentController presentViewController:navController animated:YES completion:nil];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.title = @"选择套壳模板";
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)];
    
    // 获取所有可用套壳模板文件夹
    [self loadAvailableFrameFolders];
}

- (void)loadAvailableFrameFolders {
    NSMutableArray *availableFolders = [NSMutableArray array];
    NSString *syBasePath = @"/var/mobile/SY";
    
    // 添加默认选项
    [availableFolders addObject:@"默认套壳"];
    
    // 检查SY目录是否存在
    BOOL isDir;
    if ([[NSFileManager defaultManager] fileExistsAtPath:syBasePath isDirectory:&isDir] && isDir) {
        NSError *error;
        NSArray *subdirectories = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:syBasePath error:&error];
        
        if (!error) {
            for (NSString *subdir in subdirectories) {
                NSString *fullPath = [syBasePath stringByAppendingPathComponent:subdir];
                NSString *framePath = [fullPath stringByAppendingPathComponent:@"tk.png"];
                
                // 只显示包含套壳模板图片的文件夹
                if ([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] && 
                    isDir && 
                    [[NSFileManager defaultManager] fileExistsAtPath:framePath]) {
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
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"];
    NSString *selectedFolder = [prefs objectForKey:@FRAME_FOLDER_KEY];
    
    if ((indexPath.row == 0 && (!selectedFolder || [selectedFolder isEqualToString:@"默认套壳"])) || 
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
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist"]];
    
    if (indexPath.row == 0) {
        [prefs removeObjectForKey:@FRAME_FOLDER_KEY];
    } else {
        [prefs setObject:selectedFolder forKey:@FRAME_FOLDER_KEY];
    }
    
    [prefs writeToFile:@"/var/mobile/Library/Preferences/" PREFS_IDENTIFIER ".plist" atomically:YES];
    
    // 通知设置更改
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), 
                                        CFSTR(PREFS_IDENTIFIER "/preferencesChanged"), 
                                        NULL, NULL, YES);
    
    if (self.completionHandler) {
        self.completionHandler(selectedFolder);
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end