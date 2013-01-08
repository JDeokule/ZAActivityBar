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

@interface ZAActivityAction : NSObject
@property (nonatomic,strong) NSString *name;
@property (nonatomic,strong) NSString *status;
@end

@implementation ZAActivityAction
@end

///////////////////////////////////////////////////////////////

@interface ZAActivityBar () {
    
    // Why use a dictionary and an array?
    // We need order as well as reference data, so they work together.
    
    NSMutableArray *_actionArray;
    NSMutableDictionary *_actionDict;
}

@property BOOL isVisible;

@property (nonatomic, strong, readonly) NSTimer *fadeOutTimer;
@property (nonatomic, strong, readonly) UIWindow *overlayWindow;
@property (nonatomic, strong, readonly) UIView *barView;
@property (nonatomic, strong, readonly) UILabel *stringLabel;
@property (nonatomic, strong, readonly) UIActivityIndicatorView *spinnerView;
@property (nonatomic, strong, readonly) UIImageView *imageView;

- (void) showWithStatus:(NSString *)status forAction:(NSString *)action;
- (void) setStatus:(NSString*)string;
- (void) showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration forAction:(NSString *)action;

- (void) dismissAll;
- (void) dismissForAction:(NSString *)action;

@end

@implementation ZAActivityBar

@synthesize fadeOutTimer, overlayWindow, barView, stringLabel, spinnerView, imageView;

///////////////////////////////////////////////////////////////

#pragma mark - Action Methods

- (ZAActivityAction *) getPrimaryAction {
    
    if (_actionArray.count == 0)
        return nil;
    
    NSString *action = [_actionArray objectAtIndex:0];
    return [self getAction:action];
    
}

- (ZAActivityAction *) getAction:(NSString *)action {
    
    if (![self actionExists:action])
        return nil;

    return [_actionDict objectForKey:action];
}

- (void) addAction:(NSString *)action withStatus:(NSString *)status {

    ZAActivityAction *a = [self getAction:action];
    
    if (!a) {
        [_actionArray addObject:action];
        a = [ZAActivityAction new];
        a.name = action;
    }

    a.status = status;

    [_actionDict setObject:a forKey:action];
    
}

- (void) removeAction:(NSString *)action {

    if (![self actionExists:action])
        return;

    [_actionDict removeObjectForKey:action];
    [_actionArray removeObject:action];

}

- (BOOL) isPrimaryAction:(NSString *)action {

    if (![self actionExists:action])
        return NO;
    
    NSUInteger index = [_actionArray indexOfObject:action];
    return index == 0;
    
}

- (BOOL) actionExists:(NSString *)action {
    return [_actionArray containsObject:action];
}

///////////////////////////////////////////////////////////////

#pragma mark - Show Methods

+ (void) showWithStatus:(NSString *)status {
    [ZAActivityBar showWithStatus:status forAction:DEFAULT_ACTION];
}

+ (void) showWithStatus:(NSString *)status andBottomOffset:(CGFloat) offset animated:(BOOL)animated {
    [[ZAActivityBar sharedView] showWithStatus:status forAction:DEFAULT_ACTION andOffset:[NSNumber numberWithFloat:offset] animated:animated];
}

+ (void) showWithStatus:(NSString *)status forAction:(NSString *)action {
    [[ZAActivityBar sharedView] showWithStatus:status forAction:action];
}

+ (void) show {
    [ZAActivityBar showForAction:DEFAULT_ACTION];
}

+ (void) showForAction:(NSString *)action {
    [[ZAActivityBar sharedView] showWithStatus:nil forAction:action];
}

- (void) showWithStatus:(NSString *)status forAction:(NSString *)action {
    [self showWithStatus:status forAction:action andOffset:nil animated:YES];
}

- (void) showWithStatus:(NSString *)status forAction:(NSString *)action andOffset:(NSNumber *)offset animated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        if(!self.superview)
            [self.overlayWindow addSubview:self];
        
        self.fadeOutTimer = nil;
        self.imageView.hidden = YES;

        [self.overlayWindow setHidden:NO];
        [self.spinnerView startAnimating];

        // Add the action
        [self addAction:action withStatus:status];
        
        // Only continue if the action should be visible.
        BOOL isPrimaryAction = [self isPrimaryAction:action];
        if (!isPrimaryAction)
            return;

        [self setStatus:status];
        
        if (!_isVisible) {
            _isVisible = YES;
            
            // We want to remove the previous animations
            [self removeAnimationForKey:ZA_ANIMATION_DISMISS_KEY];
            id bounceFinalValue = [NSNumber numberWithFloat:[self getBarYPositionWithBottomOffset:offset]];

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

                [self.barView.layer addAnimation:bounceAnimation forKey:@"showAnimation"];
            }

            CGPoint position = self.barView.layer.position;
            position.y = [bounceFinalValue floatValue];
            [self.barView.layer setPosition:position];
        }
        
    });
}

+ (void) showSuccessWithStatus:(NSString *)status {
    [ZAActivityBar showSuccessWithStatus:status forAction:DEFAULT_ACTION];
}

+ (void) showSuccessWithStatus:(NSString *)status forAction:(NSString *)action {
    [ZAActivityBar showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/success.png"]
                      status:status
                   forAction:action];
}

+ (void) showErrorWithStatus:(NSString *)status {
    [ZAActivityBar showErrorWithStatus:status forAction:DEFAULT_ACTION];
}

+ (void) showErrorWithStatus:(NSString *)status forAction:(NSString *)action {
    [ZAActivityBar showImage:[UIImage imageNamed:@"ZAActivityBar.bundle/error.png"]
                      status:status
                   forAction:action];
}

+ (void)showImage:(UIImage *)image status:(NSString *)status {
    [ZAActivityBar showImage:image status:status forAction:DEFAULT_ACTION];
}

+ (void)showImage:(UIImage *)image status:(NSString *)status forAction:(NSString *)action {
    [[ZAActivityBar sharedView] showImage:image
                                   status:status
                                 duration:.8
                                forAction:action];
}

- (void)showImage:(UIImage*)image status:(NSString*)status duration:(NSTimeInterval)duration forAction:(NSString *)action {
    
    // Add the action if it doesn't exist yet
    if (![self actionExists:action]) {
        [self addAction:action withStatus:status];
    }
    
    // Only continue if the action should be visible.
    BOOL isPrimaryAction = [self isPrimaryAction:action];
    if (!isPrimaryAction) {
        [self removeAction:action];
        return;
    }
    
    if(![ZAActivityBar isVisible])
        [ZAActivityBar showForAction:action];
    
    dispatch_async(dispatch_get_main_queue(), ^{

        self.imageView.image = image;
        self.imageView.hidden = NO;
        [self setStatus:status];
        [self.spinnerView stopAnimating];
        
        self.fadeOutTimer = [NSTimer scheduledTimerWithTimeInterval:duration
                                                             target:self
                                                           selector:@selector(dismissFromTimer:)
                                                           userInfo:action
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
	self.stringLabel.frame = labelRect;
	
}

+ (BOOL)isVisible {
    return [[ZAActivityBar sharedView] isVisible];
}

///////////////////////////////////////////////////////////////

#pragma mark - Dismiss Methods

+ (void) dismiss {
    [[ZAActivityBar sharedView] dismissAll];
}

+ (void) dismissForAction:(NSString *)action {
	[[ZAActivityBar sharedView] dismissForAction:action];
}

- (void) dismissAll {

    for (int i = (_actionArray.count - 1); i >= 0; i--) {
        NSString *action = [_actionArray objectAtIndex:i];
        
        // First item (visible one)
        if (i == 0) {
            [self dismissForAction:action];
        }
        // Non-visible items
        else {
            [self removeAction:action];
        }
    }
}

- (void) dismissForAction:(NSString *)action {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        // Check if the action is on the screen
        BOOL onScreen = [self isPrimaryAction:action];
        
        // Remove the action
        [self removeAction:action];

        // If this is the currently visible action, then let's do some magic
        if (onScreen) {
            
            // Let's get the new primary action
            ZAActivityAction *primaryAction = [self getPrimaryAction];
            
            // And just update the visual.
            if (primaryAction) {
                [ZAActivityBar showWithStatus:primaryAction.status forAction:primaryAction.name];
                return;
            }
            
        }
        // If it's not visible, don't continue.
        else {
            return;
        }

        if (_isVisible) {
            _isVisible = NO;
            
            // If the animation is midway through, we want it to drop immediately
            BOOL shouldDrop = [self.barView.layer.animationKeys containsObject:ZA_ANIMATION_SHOW_KEY];

            // We want to remove the previous animations
            [self removeAnimationForKey:ZA_ANIMATION_SHOW_KEY];
            
            // Setup the animation values
            NSString *keypath = @"position.y";
            id currentValue = [NSNumber numberWithFloat:self.barView.layer.position.y];
            id midValue = [NSNumber numberWithFloat:self.barView.layer.position.y - 7];
            id finalValue = [NSNumber numberWithFloat:[self getOffscreenYPosition]];
            
            CAMediaTimingFunction *function = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn];
            NSArray *keyTimes = (shouldDrop ? @[@0.0,@0.3] : @[@0.0,@0.3,@0.5]);
            NSArray *values = (shouldDrop ? @[currentValue,finalValue] : @[currentValue,midValue,finalValue]);
            NSArray *timingFunctions = (shouldDrop ? @[function, function] : @[function, function, function]);
            
            // Get the duration. So we don't have to manually set it, this defaults to the final value in the animation keys.
            float duration = [[keyTimes objectAtIndex:(keyTimes.count - 1)] floatValue];
            
            // Perform the animation
            CAKeyframeAnimation *frameAnimation = [CAKeyframeAnimation animationWithKeyPath:keypath];
//            [frameAnimation setCalculationMode:kCAAnimationLinear]; Defaults to Linear.
            [frameAnimation setKeyTimes:keyTimes];
            [frameAnimation setValues:values];
            [frameAnimation setTimingFunctions:timingFunctions];
            [frameAnimation setDuration:duration];
            [frameAnimation setRemovedOnCompletion:YES];
            
            [self.barView.layer addAnimation:frameAnimation forKey:ZA_ANIMATION_DISMISS_KEY];
            
            CGPoint position = self.barView.layer.position;
            position.y = [finalValue floatValue];
            [self.barView.layer setPosition:position];
        }
    });
}

- (void) dismissFromTimer:(NSTimer *)timer {
    NSString *action = timer.userInfo;
    [ZAActivityBar dismissForAction:action];
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

- (void)drawRect:(CGRect)rect {
    
}

- (void)dealloc {
	self.fadeOutTimer = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)setFadeOutTimer:(NSTimer *)newTimer {
    
    if(fadeOutTimer)
        [fadeOutTimer invalidate], fadeOutTimer = nil;
    
    if(newTimer)
        fadeOutTimer = newTimer;
}

- (id)initWithFrame:(CGRect)frame {
	
    if ((self = [super initWithFrame:frame])) {
		self.userInteractionEnabled = NO;
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _isVisible = NO;
        _actionArray = [NSMutableArray new];
        _actionDict = [NSMutableDictionary new];
    }
	
    return self;
}

+ (ZAActivityBar *) sharedView {
    static dispatch_once_t once;
    static ZAActivityBar *sharedView;
    dispatch_once(&once, ^ { sharedView = [[ZAActivityBar alloc] initWithFrame:[[UIScreen mainScreen] bounds]]; });
    return sharedView;
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

- (UIWindow *)overlayWindow {
    if(!overlayWindow) {
        overlayWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
        overlayWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlayWindow.backgroundColor = [UIColor clearColor];
        overlayWindow.userInteractionEnabled = NO;
    }
    return overlayWindow;
}

- (UIView *)barView {
    if(!barView) {
        CGRect rect = CGRectMake(0, FLT_MAX, self.frame.size.width, HEIGHT);
//        rect.size.width -= 2 * PADDING;
        rect.origin.y = [self getOffscreenYPosition];
        barView = [[UIView alloc] initWithFrame:rect];
//        barView.layer.cornerRadius = 6;
		barView.backgroundColor = BAR_COLOR;
        barView.autoresizingMask = (UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleWidth);
        [self addSubview:barView];
    }
    
    return barView;
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

+ (void) moveToBottom
{
    ZAActivityBar *bar = [ZAActivityBar sharedView];

    if ([bar isVisible]) {
        CGPoint position = bar.barView.layer.position;
        position.y = [bar getBarYPosition];
        [bar.barView.layer setPosition:position];
    }
}

+ (void) moveToOffset:(CGFloat)offset
{
    ZAActivityBar *bar = [ZAActivityBar sharedView];

    if ([bar isVisible]) {
        CGPoint position = bar.barView.layer.position;
        position.y = [bar getBarYPositionWithBottomOffset:[NSNumber numberWithFloat:offset]];
        [bar.barView.layer setPosition:position];
    }
    
}

@end
