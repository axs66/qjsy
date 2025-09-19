#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

// 水印文件夹选择器界面
@interface WatermarkFolderSelector : UITableViewController

@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, copy) void (^completionHandler)(NSString *selectedFolder);

+ (void)presentFromViewController:(UIViewController *)parentController completion:(void (^)(NSString *))completion;

@end

NS_ASSUME_NONNULL_END