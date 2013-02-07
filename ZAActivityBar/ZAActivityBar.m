//
//  ZAActivityBar.m
//
//  Created by Zac Altman on 24/11/12.
//  Copyright (c) 2012 Zac Altman. All rights reserved.
//

#import "ZAActivityBar.h"
#import <QuartzCore/QuartzCore.h>
#import "SKBounceAnimation.h"

#define ZA_ANIMATION_SHOW_KEY @"showAnimation"
#define ZA_ANIMATION_DISMISS_KEY @"dismissAnimation"


///////////////////////////////////////////////////////////////

@interface ZAActivityBar ()

@property BOOL isVisible;

@property (nonatomic, strong, readonly) NSTimer *fadeOutTimer;
@property (nonatomic, strong, readonly) UIView *barView;
@property (nonatomic, strong, readonly) UILabel *stringLabel;
@property (nonatomic, strong, readonly) UIActivityIndicatorView *spinnerView;
@property (nonatomic, strong, readonly) UIImageView *imageView;

@end

@implementation ZAActivityBar

@synthesize fadeOutTimer, barView, stringLabel, spinnerView, imageView;

@synthesize tapToDismiss = _tapToDismiss;

static int counter = 0;

///////////////////////////////////////////////////////////////

#pragma mark - Class Methods

+ (ZAActivityBar *) showWithStatus:(NSString *)status inView:(UIView *)view {
    return [ZAActivityBar showWithStatus:status animated:YES inView:view];
}

+ (ZAActivityBar *) showWithStatus:(NSString *)status animated:(BOOL)animated inView:(UIView *)view
{
    ZAActivityBar *bar = [[ZAActivityBar alloc] initWithParentView:view];

    [bar showWithStatus:status animated:animated];

    return bar;
}

+ (ZAActivityBar *) showSuccessWithStatus:(NSString *)status inView:(UIView *)view {
    return [ZAActivityBar showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/success.png"]
                      status:status
                      inView:view];
}

+ (ZAActivityBar *) showErrorWithStatus:(NSString *)status inView:(UIView *)view {
    return [ZAActivityBar showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/error.png"]
                      status:status
                      inView:view];
}

+ (ZAActivityBar *) showImage:(UIImage *)image status:(NSString *)status inView:(UIView *)view {
    ZAActivityBar *bar = [[ZAActivityBar alloc] initWithParentView:view];

    [bar showImage:image
            status:status
          duration:.75];

    return bar;
}


#pragma mark - Show methods

- (void) showWithStatus:(NSString *)status {
    [self showWithStatus:status animated:YES];
}

- (void) showWithStatus:(NSString *)status animated:(BOOL)animated {
    self.fadeOutTimer = nil;
    self.imageView.hidden = YES;

    [self.spinnerView startAnimating];

    [self setStatus:status];

    if (!_isVisible) {
        _isVisible = YES;

        // We want to remove the previous animations
        [self removeAnimationForKey:ZA_ANIMATION_DISMISS_KEY];
        id bounceFinalValue = [NSNumber numberWithFloat:[self getBarYPosition]];
        
        if (animated) {
            NSString *bounceKeypath = @"position.y";
            id bounceOrigin = [NSNumber numberWithFloat:self.barView.layer.position.y];
            
            SKBounceAnimation *bounceAnimation = [SKBounceAnimation animationWithKeyPath:bounceKeypath];
            bounceAnimation.fromValue = bounceOrigin;
            bounceAnimation.toValue = bounceFinalValue;
            bounceAnimation.shouldOvershoot = YES;
            bounceAnimation.numberOfBounces = 4;
            bounceAnimation.delegate = self;
            bounceAnimation.removedOnCompletion = YES;
            bounceAnimation.duration = 0.7f;
            
            [self.barView.layer addAnimation:bounceAnimation forKey:ZA_ANIMATION_SHOW_KEY];

            [self setHidden:NO];
        } else {
            self.alpha = 0.0f;
            [self setHidden:NO];
            
            [UIView animateWithDuration:.15
                                  delay:0
                                options:0
                             animations:^(void) {
                                 [self setAlpha:1];
                             } completion:^(BOOL finished) {
                                 RKLogInfo(@"Finished showing the bar i think");
                             }];
        }
        
        CGPoint position = self.barView.layer.position;
        position.y = [bounceFinalValue floatValue];
        [self.barView.layer setPosition:position];
    } else {
        self.alpha = 0.0f;
        [self setHidden:NO];

        [UIView animateWithDuration:.15
                              delay:0
                            options:0
                         animations:^(void) {
                             [self setAlpha:1];
                         } completion:^(BOOL finished) {
                             RKLogInfo(@"Finished showing the bar i think");
                         }];
    }
    
}

- (void) showSuccessWithStatus:(NSString *)status
{
    [self showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/success.png"] status:status duration:.8];
}

- (void) showErrorWithStatus:(NSString *)status
{
    [self showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/error.png"] status:status duration:.8];
}

- (void) showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration
{
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = image;
        self.imageView.hidden = NO;
        [self setStatus:status];
        [self.spinnerView stopAnimating];

        self.fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:duration
                                                             target:self
                                                           selector:@selector(dismissFromTimer:)
                                                           userInfo:nil
                                                            repeats:NO];
    });

}

///////////////////////////////////////////////////////////////

#pragma mark - Property Methods

- (void)setStatus:(NSString *)string {
	
    CGFloat stringWidth = 0;
    CGFloat stringHeight = 0;
    CGRect labelRect = CGRectZero;
    
    if(string) {
        float offset = (SPINNER_SIZE + 2 * ICON_OFFSET);
        float width = self.barView.frame.size.width - offset;
        CGSize stringSize = [string sizeWithFont:self.stringLabel.font
                               constrainedToSize:CGSizeMake(width, 300)];
        stringWidth = stringSize.width;
        stringHeight = stringSize.height;

        labelRect = CGRectMake(offset, 0, stringWidth, HEIGHT);
        
    }
	
	self.stringLabel.hidden = NO;
	self.stringLabel.text = string;
    counter++;
	self.stringLabel.frame = labelRect;	
}


///////////////////////////////////////////////////////////////

#pragma mark - Dismiss Methods

- (void) dismiss {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self removeAnimationForKey:ZA_ANIMATION_SHOW_KEY];

        id finalValue = [NSNumber numberWithFloat:[self getOffscreenYPosition]];
        
        
        [UIView animateWithDuration:.35
                              delay:0
                            options:UIViewAnimationOptionAllowUserInteraction
                         animations:^(void) {
                             CGPoint position = self.barView.layer.position;
                             position.y = [finalValue floatValue];
                             [self.barView.layer setPosition:position];
                         }
                         completion:^(BOOL finished) {
                             [self removeFromSuperview];
                         }];
    });
}

- (void) dismissFromTimer:(NSTimer *)timer {
    [self dismiss];
}

///////////////////////////////////////////////////////////////

#pragma mark - Helpers

- (float) getOffscreenYPosition {
    return self.frame.size.height + ((HEIGHT / 2) + PADDING);
}

- (float) getBarYPosition {
    return [self getBarYPositionWithBottomOffset:nil];
}

- (float) getBarYPositionWithBottomOffset:(NSNumber *)offset {
    return self.frame.size.height - (HEIGHT / 2) - (offset ? [offset floatValue] : BOTTOM_OFFSET);
}

- (void) setYOffset:(float)yOffset {
    CGRect rect = self.barView.frame;
    rect.origin.y = yOffset;
    [self.barView setFrame:rect];
}

///////////////////////////////////////////////////////////////

#pragma mark - Animation Methods / Helpers

// For some reason the SKBounceAnimation isn't removed if this method
// doesn't exist... Why?
- (void) animationDidStop:(CAAnimation *)anim finished:(BOOL)flag {
}

- (void) removeAnimationForKey:(NSString *)key {
    if ([self.barView.layer.animationKeys containsObject:key]) {
        CAAnimation *anim = [self.barView.layer animationForKey:key];
        
        // Find out how far into the animation we made it
        CFTimeInterval startTime = [[anim valueForKey:@"beginTime"] floatValue];
        CFTimeInterval pausedTime = [self.barView.layer convertTime:CACurrentMediaTime() fromLayer:nil];
        float diff = pausedTime - startTime;
        
        // We only need a ~rough~ frame, so it doesn't jump to the end position
        // and stays as close to in place as possible.
        int frame = (diff * 58.57 - 1); // 58fps?
        NSArray *frames = [anim valueForKey:@"values"];
        if (frame >= frames.count)  // For security
            frame = frames.count - 1;
        
        float yOffset = [[frames objectAtIndex:frame] floatValue];
        
        // And lets set that
        CGPoint position = self.barView.layer.position;
        position.y = yOffset;
        
        // We want to disable the implicit animation
        [CATransaction begin];
        [CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
        [self.barView.layer setPosition:position];
        [CATransaction commit];
        
        // And... actually remove it.
        [self.barView.layer removeAnimationForKey:key];
    }
}

///////////////////////////////////////////////////////////////

#pragma mark - Misc

- (void)setFadeOutTimer:(NSTimer *)newTimer {
    
    if(fadeOutTimer)
        [fadeOutTimer invalidate], fadeOutTimer = nil;
    
    if(newTimer)
        fadeOutTimer = newTimer;
}

- (id) initWithParentView:(UIView *) parent
{
    CGRect theFrame = CGRectMake(0, parent.bounds.size.height - HEIGHT, parent.bounds.size.width, HEIGHT);

    if (self = [super initWithFrame:theFrame]) {
        [self commonInit];
    }

    [parent addSubview:self];

    return self;
}

- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])) {
        [self commonInit];
    }

    return self;
}
            
- (void) commonInit
{
    self.userInteractionEnabled = YES;
    self.backgroundColor = [UIColor clearColor];
    self.opaque = YES;
    self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _isVisible = NO;

    self.tapToDismiss = YES;
}

///////////////////////////////////////////////////////////////

#pragma mark - Getters

- (UILabel *)stringLabel {
    if (stringLabel == nil) {
        stringLabel = [[UILabel alloc] initWithFrame:CGRectZero];
		stringLabel.textColor = [UIColor whiteColor];
		stringLabel.backgroundColor = [UIColor clearColor];
		stringLabel.adjustsFontSizeToFitWidth = YES;
		stringLabel.textAlignment = NSTextAlignmentLeft;
		stringLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
		stringLabel.font = [UIFont boldSystemFontOfSize:14];
		stringLabel.shadowColor = [UIColor blackColor];
		stringLabel.shadowOffset = CGSizeMake(0, -1);
        stringLabel.numberOfLines = 0;
    }
    
    if(!stringLabel.superview)
        [self.barView addSubview:stringLabel];
    
    return stringLabel;
}

//- (UIWindow *)overlayWindow {
//    if(!overlayWindow) {
//        CGRect bounds = [UIScreen mainScreen].bounds;
//        CGRect theFrame = CGRectMake(bounds.origin.x, bounds.origin.y, bounds.size.width, HEIGHT);
//        overlayWindow = [[UIWindow alloc] initWithFrame:theFrame];
//        overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
//        overlayWindow.backgroundColor = [UIColor clearColor];
//        overlayWindow.userInteractionEnabled = YES;
//    }
//    return overlayWindow;
//}

- (UIView *)barView {
    if(!barView) {
        CGRect rect = CGRectMake(0, FLT_MAX, self.frame.size.width, HEIGHT);
//        rect.size.width -= 2 * PADDING;
        rect.origin.y = [self getOffscreenYPosition];
        barView = [[UIView alloc] initWithFrame:rect];
//        barView.layer.cornerRadius = 6;
		barView.backgroundColor = BAR_COLOR;
        barView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);

        barView.userInteractionEnabled = YES;

        if (self.tapToDismiss)
            [barView addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(barPressed:)]];

        [self addSubview:barView];
    }
    
    return barView;
}

- (void) barPressed:(UIGestureRecognizer *)gesture
{
    [self dismiss];
}

- (UIActivityIndicatorView *)spinnerView {
    if (spinnerView == nil) {
        spinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
		spinnerView.hidesWhenStopped = YES;
		spinnerView.frame = CGRectMake(ICON_OFFSET, ICON_OFFSET, SPINNER_SIZE, SPINNER_SIZE);
    }
    
    if(!spinnerView.superview)
        [self.barView addSubview:spinnerView];
    
    return spinnerView;
}

- (UIImageView *)imageView {
    if (imageView == nil)
        imageView = [[UIImageView alloc] initWithFrame:CGRectMake(ICON_OFFSET, ICON_OFFSET, SPINNER_SIZE, SPINNER_SIZE)];

    if(!imageView.superview)
        [self.barView addSubview:imageView];

    return imageView;
}

//+ (void) moveToBottom
//{
//    ZAActivityBar *bar = [ZAActivityBar sharedView];
//
//    if ([bar isVisible]) {
//        CGPoint position = bar.barView.layer.position;
//        position.y = [bar getBarYPosition];
//        [bar.barView.layer setPosition:position];
//    }
//}
//
//+ (void) moveToOffset:(CGFloat)offset
//{
//    ZAActivityBar *bar = [ZAActivityBar sharedView];
//
//    if ([bar isVisible]) {
//        CGPoint position = bar.barView.layer.position;
//        position.y = [bar getBarYPositionWithBottomOffset:[NSNumber numberWithFloat:offset]];
//        [bar.barView.layer setPosition:position];
//    }
//    
//}

@end
