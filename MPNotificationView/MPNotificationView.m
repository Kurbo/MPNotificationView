//
//  MPNotificationView.m
//  Moped
//
//  Created by Engin Kurutepe on 1/2/13.
//  Copyright (c) 2013 Moped Inc. All rights reserved.
//

#import "MPNotificationView.h"

#define kMPNotificationHeight    60.0f

#define kMPNotificationIPadWidth 480.0f
#define RADIANS(deg) ((deg) * M_PI / 180.0f)

static NSMutableDictionary * _registeredTypes;

static CGFloat notificationHeight() {
    CGFloat height = kMPNotificationHeight;
    return height;
}

static CGRect notificationRect()
{
    if (UIInterfaceOrientationIsLandscape([[UIApplication sharedApplication] statusBarOrientation]))
    {
        return CGRectMake(0.0f, 0.0f,
                          [UIScreen mainScreen].bounds.size.height,
                          notificationHeight());
    }
    
    return CGRectMake(0.0f, 0.0f,
                      [UIScreen mainScreen].bounds.size.width,
                      notificationHeight());
}

NSString *kMPNotificationViewTapReceivedNotification = @"kMPNotificationViewTapReceivedNotification";

#pragma mark MPNotificationWindow

@interface MPNotificationWindow : UIWindow

@property (nonatomic, strong) NSMutableArray *notificationQueue;
@property (nonatomic, strong) UIView *currentNotification;

@end

@implementation MPNotificationWindow

- (void) dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.windowLevel = UIWindowLevelStatusBar + 1;
        self.backgroundColor = [UIColor clearColor];
        _notificationQueue = [[NSMutableArray alloc] initWithCapacity:4];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(willRotateScreen:)
                                                     name:UIApplicationWillChangeStatusBarFrameNotification
                                                   object:nil];
        
        [self rotateNotificationWindow];
    }
    
    return self;
}

- (void) willRotateScreen:(NSNotification *)notification
{
    if (self.hidden)
    {
        double delayInSeconds = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
        dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
        dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
            [self rotateNotificationWindow];
        });
    }
    else
    {
        [self rotateNotificationWindowAnimated];
    }
}

- (void) rotateNotificationWindowAnimated
{
    CGFloat duration = [UIApplication sharedApplication].statusBarOrientationAnimationDuration;
    [UIView animateWithDuration:duration
                     animations:^{
                         self.alpha = 0;
                     } completion:^(BOOL finished) {
                         [self rotateNotificationWindow];
                         [UIView animateWithDuration:duration
                                          animations:^{
                                              self.alpha = 1;
                                          }];
                     }];
}


- (void) rotateNotificationWindow
{
    CGRect frame = notificationRect();
    BOOL isPortrait = (frame.size.width == [UIScreen mainScreen].bounds.size.width);
    
    if (isPortrait)
    {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            frame.size.width = kMPNotificationIPadWidth;
        }
        
        if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationPortraitUpsideDown)
        {
            frame.origin.y = [UIScreen mainScreen].bounds.size.height - notificationHeight();
            self.transform = CGAffineTransformMakeRotation(RADIANS(180.0f));
        }
        else
        {
            self.transform = CGAffineTransformIdentity;
        }
    }
    else
    {
        frame.size.height = frame.size.width;
        frame.size.width  = notificationHeight();
        
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        {
            frame.size.height = kMPNotificationIPadWidth;
        }
        
        if ([[UIDevice currentDevice] orientation] == UIDeviceOrientationLandscapeLeft)
        {
            frame.origin.x = [UIScreen mainScreen].bounds.size.width - frame.size.width;
            self.transform = CGAffineTransformMakeRotation(RADIANS(90.0f));
        }
        else
        {
            self.transform = CGAffineTransformMakeRotation(RADIANS(-90.0f));
        }
    }
    
    self.frame = frame;
    CGPoint center = self.center;
    if (isPortrait)
    {
        center.x = CGRectGetMidX([UIScreen mainScreen].bounds);
    }
    else
    {
        center.y = CGRectGetMidY([UIScreen mainScreen].bounds);
    }
    self.center = center;
}

@end


static MPNotificationWindow * __notificationWindow = nil;
static CGFloat const __imagePadding = 8.0f;

#pragma mark -
#pragma mark MPNotificationView

@interface MPNotificationView ()


@property (nonatomic, strong) UIView * contentView;
@property (nonatomic, copy) MPNotificationSimpleAction tapBlock;
@property (nonatomic, strong) UITapGestureRecognizer *tapGestureRecognizer;

+ (UIImage*) screenImageWithRect:(CGRect)rect;

@end

@implementation MPNotificationView

- (void) dealloc
{
    _delegate = nil;
    [self removeGestureRecognizer:_tapGestureRecognizer];
}

- (id) initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        CGFloat notificationWidth = notificationRect().size.width;
        
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        UIToolbar * toolbar = [[UIToolbar alloc] initWithFrame:self.bounds];
        
        toolbar.barTintColor = [UIColor blackColor];
        _contentView = toolbar;
        [self addSubview:_contentView];
            
        CGFloat imageViewEdgeLength;
        CGFloat imageCornerRoundness;
        imageViewEdgeLength = 20;
        imageCornerRoundness = 3;
        _imageView = [[UIImageView alloc] initWithFrame:CGRectMake(6, 6, imageViewEdgeLength, imageViewEdgeLength)];
        _imageView.contentMode = UIViewContentModeScaleAspectFill;
        _imageView.layer.cornerRadius = imageCornerRoundness;
        _imageView.clipsToBounds = YES;
        [self addSubview:_imageView];
        
        UIColor *textColor = [UIColor whiteColor];
        
        UIFont *textFont = [UIFont boldSystemFontOfSize:14.0f];
        CGRect textFrame = CGRectMake(__imagePadding + CGRectGetMaxX(_imageView.frame),
                                      2,
                                      notificationWidth - __imagePadding * 2 - CGRectGetMaxX(_imageView.frame),
                                      textFont.lineHeight);
        _textLabel = [[UILabel alloc] initWithFrame:textFrame];
        _textLabel.font = textFont;
        _textLabel.numberOfLines = 1;
        _textLabel.textAlignment = UITextAlignmentLeft;
        _textLabel.lineBreakMode = UILineBreakModeTailTruncation;
        _textLabel.backgroundColor = [UIColor clearColor];
        _textLabel.textColor = textColor;
        [_contentView addSubview:_textLabel];
        
        UIFont *detailFont = [UIFont systemFontOfSize:13.0f];
        CGRect detailFrame = CGRectMake(CGRectGetMinX(textFrame),
                                        CGRectGetMaxY(textFrame),
                                        notificationWidth - __imagePadding * 2 - CGRectGetMaxX(_imageView.frame),
                                        detailFont.lineHeight);
        
        _detailTextLabel = [[UILabel alloc] initWithFrame:detailFrame];
        _detailTextLabel.font = detailFont;
        _detailTextLabel.numberOfLines = 1;
        _detailTextLabel.textAlignment = UITextAlignmentLeft;
        _detailTextLabel.lineBreakMode = UILineBreakModeTailTruncation;
        _detailTextLabel.backgroundColor = [UIColor clearColor];
        _detailTextLabel.textColor = textColor;
        [_contentView addSubview:_detailTextLabel];
    }
    
    return self;
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                              andDetail:(NSString*)detail
{
    return [self notifyWithText:text
                         detail:detail
                    andDuration:4.0f];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                            andDuration:(NSTimeInterval)duration
{
    return [self notifyWithText:text
                         detail:detail
                          image:nil
                    andDuration:duration];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                                  image:(UIImage*)image
                            andDuration:(NSTimeInterval)duration
{
    return [self notifyWithText:text
                         detail:detail
                          image:image
                       duration:duration
                  andTouchBlock:nil];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                               duration:(NSTimeInterval)duration
                          andTouchBlock:(MPNotificationSimpleAction)block
{
    return [self notifyWithText:text
                         detail:detail
                          image:nil
                       duration:duration
                  andTouchBlock:block];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                          andTouchBlock:(MPNotificationSimpleAction)block
{
    return [self notifyWithText:text
                         detail:detail
                          image:nil
                       duration:2.0
                  andTouchBlock:block];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                                  image:(UIImage*)image
                               duration:(NSTimeInterval)duration
                          andTouchBlock:(MPNotificationSimpleAction)block
{
    return [self notifyWithText:text
                         detail:detail
                          image:image
                       duration:duration
                           type:nil
                  andTouchBlock:block];
}

+ (MPNotificationView *) notifyWithText:(NSString*)text
                                 detail:(NSString*)detail
                                  image:(UIImage*)image
                               duration:(NSTimeInterval)duration
                                   type:(NSString *)type
                          andTouchBlock:(MPNotificationSimpleAction)block
{
    if (__notificationWindow == nil)
    {
        __notificationWindow = [[MPNotificationWindow alloc] initWithFrame:notificationRect()];
        __notificationWindow.hidden = NO;
    }
    
    MPNotificationView * notification;
    id nibNameOrClass = type ? _registeredTypes[type] : nil;
    if ([nibNameOrClass isKindOfClass:[NSString class]])
    {
        notification = [[NSBundle mainBundle] loadNibNamed:nibNameOrClass
                                                     owner:nil
                                                   options:nil][0];
        notification.frame = __notificationWindow.bounds;
    }
    else if (!nibNameOrClass)
    {
        notification = [[MPNotificationView alloc] initWithFrame:__notificationWindow.bounds];
    }
    else
    {
        notification = [[nibNameOrClass alloc] initWithFrame:__notificationWindow.bounds];
    }
    
    notification.textLabel.text = text;
    notification.detailTextLabel.text = detail;
    notification.imageView.image = image;
    notification.duration = duration;
    notification.tapBlock = block;
    
    UITapGestureRecognizer *gr = [[UITapGestureRecognizer alloc] initWithTarget:notification
                                                                         action:@selector(handleTap:)];
    notification.tapGestureRecognizer = gr;
    [notification addGestureRecognizer:gr];
    
    [__notificationWindow.notificationQueue addObject:notification];
    
    if (__notificationWindow.currentNotification == nil)
    {
        [self showNextNotification];
    }
    
    return notification;
}

+ (void)registerNibNameOrClass:(id)nibNameOrClass
        forNotificationsOfType:(NSString *)type
{
    if (!_registeredTypes)
        _registeredTypes = [NSMutableDictionary dictionary];
    
    _registeredTypes[type] = nibNameOrClass;
}

- (void) handleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    if (_tapBlock != nil)
    {
        _tapBlock(self);
    }
    
    if ([_delegate respondsToSelector:@selector(tapReceivedForNotificationView:)])
    {
        [_delegate didTapOnNotificationView:self];
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:kMPNotificationViewTapReceivedNotification
                                                        object:self];
    
    [MPNotificationView showNextNotification];
}

+ (void) performIOS7Slide {
    UIView * viewToSlideIn = nil;
    
    if ([__notificationWindow.notificationQueue count] > 0)
    {
        viewToSlideIn = __notificationWindow.notificationQueue[0];
    }
    

    
    if (viewToSlideIn) {
        viewToSlideIn.frame = CGRectOffset(notificationRect(), 0, -notificationHeight());
        
        [__notificationWindow addSubview:viewToSlideIn];
        
        
        UIView * viewToSlideOut = nil;
        
        if (__notificationWindow.currentNotification) {
            viewToSlideOut = __notificationWindow.currentNotification;
        }
        
        [UIView animateWithDuration:0.5
                         animations:^{

                             viewToSlideIn.frame = notificationRect();
                             
                             viewToSlideOut.clipsToBounds = YES;
                             viewToSlideOut.layer.bounds = CGRectMake(0, 0, viewToSlideOut.bounds.size.width, 0);
                             viewToSlideOut.layer.position = CGPointMake(viewToSlideOut.bounds.size.width/2, notificationHeight());
                             for (UIView * view in viewToSlideOut.subviews) {
                                 view.frame = CGRectOffset(view.frame, 0, -notificationHeight());
                             }
                         }
                         completion:^(BOOL finished) {
                             MPNotificationView *notification = (MPNotificationView*)viewToSlideIn;
                             
                             if (notification.duration > 0.0)
                             {
                                 [self performSelector:@selector(showNextNotification)
                                            withObject:nil
                                            afterDelay:notification.duration];
                             }
                             
                             [__notificationWindow.currentNotification removeFromSuperview];
                             __notificationWindow.currentNotification = notification;
                             [__notificationWindow.notificationQueue removeObject:notification];

                         }];
    }
    else if(__notificationWindow.currentNotification) {
        UIView * oldNotification = __notificationWindow.currentNotification;
        [UIView animateWithDuration:0.5
                         animations:^{
                             oldNotification.frame = CGRectOffset(oldNotification.frame,
                                                                  0, -notificationHeight());
                         }
                         completion:^(BOOL finished) {
                             [oldNotification removeFromSuperview];
                             __notificationWindow.hidden = YES;
                             __notificationWindow.currentNotification = nil;
                         }];
    }
}

+ (void) showNextNotification
{
    [NSObject cancelPreviousPerformRequestsWithTarget:[self class]
                                             selector:@selector(showNextNotification)
                                               object:nil];
    
    [self performIOS7Slide];
}

+ (UIImage *) screenImageWithRect:(CGRect)rect
{
    CALayer *layer = [[UIApplication sharedApplication] keyWindow].layer;
    CGFloat scale = [UIScreen mainScreen].scale;
    UIGraphicsBeginImageContextWithOptions(layer.frame.size, NO, scale);
    
    [layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage *screenshot = UIGraphicsGetImageFromCurrentImageContext();
    
    UIGraphicsEndImageContext();
    
    rect = CGRectMake(rect.origin.x * scale, rect.origin.y * scale
                      , rect.size.width * scale, rect.size.height * scale);
    
    CGImageRef imageRef = CGImageCreateWithImageInRect([screenshot CGImage], rect);
    UIImage *croppedScreenshot = [UIImage imageWithCGImage:imageRef
                                                     scale:screenshot.scale
                                               orientation:screenshot.imageOrientation];
    CGImageRelease(imageRef);
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    UIImageOrientation imageOrientation = UIImageOrientationUp;
    
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            imageOrientation = UIImageOrientationDown;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            imageOrientation = UIImageOrientationRight;
            break;
        case UIInterfaceOrientationLandscapeRight:
            imageOrientation = UIImageOrientationLeft;
            break;
        default:
            break;
    }
    
    return [[UIImage alloc] initWithCGImage:croppedScreenshot.CGImage
                                      scale:croppedScreenshot.scale
                                orientation:imageOrientation];
}

@end
