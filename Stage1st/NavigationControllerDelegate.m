//
//  NavigationControllerDelegate.m
//  Stage1st
//
//  Created by Zheng Li on 11/16/14.
//  Copyright (c) 2014 Renaissance. All rights reserved.
//

#import "NavigationControllerDelegate.h"
#import "S1Animator.h"

#define _TRIGGER_THRESHOLD 60.0f
#define _TRIGGER_VELOCITY_THRESHOLD 500.0f

@interface NavigationControllerDelegate ()

@property (weak, nonatomic) IBOutlet UINavigationController *navigationController;
@property (strong, nonatomic) S1Animator* animator;
@property (strong, nonatomic) UIPercentDrivenInteractiveTransition* interactionController;

@end


@implementation NavigationControllerDelegate

- (void)awakeFromNib
{
    UIPanGestureRecognizer* panRecognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(pan:)];
    [self.navigationController.view addGestureRecognizer:panRecognizer];
    
    self.animator = [S1Animator new];
}

- (void)pan:(UIPanGestureRecognizer*)recognizer
{
    UIView* view = self.navigationController.view;
    CGPoint translation = [recognizer translationInView:view];
    if (recognizer.state == UIGestureRecognizerStateBegan) {
        //NSLog(@"Begin, x: %f, y: %f", translation.x, translation.y);
        if (translation.x >= translation.y && self.navigationController.viewControllers.count > 1) {
            self.interactionController = [UIPercentDrivenInteractiveTransition new];
            [self.navigationController popViewControllerAnimated:YES];
        }
    }
    else if (recognizer.state == UIGestureRecognizerStateChanged) {
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        [self.interactionController updateInteractiveTransition:translation.x > 0 ? translation.x / screenWidth : 0];
        // NSLog(@"Changed：%f%%", 100 * translation.x / screenWidth);
    } else if (recognizer.state == UIGestureRecognizerStateEnded) {
        //NSLog(@"End");
        CGFloat velocityX = [recognizer velocityInView:view].x;
        CGRect screenRect = [[UIScreen mainScreen] bounds];
        CGFloat screenWidth = screenRect.size.width;
        if ((translation.x > _TRIGGER_THRESHOLD || velocityX > _TRIGGER_VELOCITY_THRESHOLD) && velocityX >= 0) {
            self.interactionController.completionSpeed = 0.3 / fmin((screenWidth - fmin(translation.x, 0)) / fabsf(velocityX), 0.3);
            NSLog(@"%f", self.interactionController.completionSpeed);
            [self.interactionController finishInteractiveTransition];
        } else {
            self.interactionController.completionSpeed = 0.3 / fmin(fabsf(translation.x / velocityX), 0.4);
            NSLog(@"%f", self.interactionController.completionSpeed);
            [self.interactionController cancelInteractiveTransition];
        }
        self.interactionController = nil;
    } else {
        NSLog(@"Other Interaction Event:%ld", recognizer.state);
        [self.interactionController cancelInteractiveTransition];
        self.interactionController = nil;
    }
}

- (id<UIViewControllerAnimatedTransitioning>)navigationController:(UINavigationController *)navigationController animationControllerForOperation:(UINavigationControllerOperation)operation fromViewController:(UIViewController *)fromVC toViewController:(UIViewController *)toVC
{
    if (operation == UINavigationControllerOperationPop) {
        return self.animator;
    }
    return nil;
}

- (id<UIViewControllerInteractiveTransitioning>)navigationController:(UINavigationController *)navigationController interactionControllerForAnimationController:(id<UIViewControllerAnimatedTransitioning>)animationController
{
    return self.interactionController;
}

- (NSUInteger)navigationControllerSupportedInterfaceOrientations:(UINavigationController *)navigationController
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    }
    return UIInterfaceOrientationMaskAll;
}

@end
