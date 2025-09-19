#import <UIKit/UIKit.h>

@interface ScreenshotWatermarkHelper : NSObject
+ (UIImage *)applyWatermarkAndPerspectiveToImage:(UIImage *)image;
@end

@implementation ScreenshotWatermarkHelper

+ (UIImage *)applyWatermarkAndPerspectiveToImage:(UIImage *)image {
    if (!image) return nil;

    CGSize size = image.size;
    UIGraphicsBeginImageContextWithOptions(size, NO, image.scale);
    CGContextRef ctx = UIGraphicsGetCurrentContext();

    // 绘制原图
    [image drawAtPoint:CGPointZero];

    // 绘制水印
    NSString *watermark = @"你的水印文字";
    NSDictionary *attrs = @{
        NSFontAttributeName: [UIFont boldSystemFontOfSize:40],
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1 alpha:0.5]
    };
    CGSize textSize = [watermark sizeWithAttributes:attrs];
    CGPoint textPoint = CGPointMake(size.width - textSize.width - 20, size.height - textSize.height - 20);
    [watermark drawAtPoint:textPoint withAttributes:attrs];

    // 透视仿射
    CGAffineTransform transform = CGAffineTransformMakeShear(0.1, 0); // X方向倾斜
    CGContextConcatCTM(ctx, transform);

    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result;
}

// 透视辅助函数
CG_INLINE CGAffineTransform CGAffineTransformMakeShear(CGFloat sx, CGFloat sy) {
    return (CGAffineTransform){1, sy, sx, 1, 0, 0};
}

@end
