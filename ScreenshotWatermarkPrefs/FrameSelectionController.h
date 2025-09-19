#import <UIKit/UIKit.h>
#import <Preferences/PSListController.h>
#import <Preferences/PSSpecifier.h>

NS_ASSUME_NONNULL_BEGIN

// 套壳模板选择器界面
@interface FrameSelectionController : UITableViewController

@property (nonatomic, strong) NSArray *folders;
@property (nonatomic, copy) void (^completionHandler)(NSString *selectedFolder);

+ (void)presentFromViewController:(UIViewController *)parentController completion:(void (^)(NSString *))completion;

@end

NS_ASSUME_NONNULL_END