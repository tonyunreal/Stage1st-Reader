//
//  S1TopicListCellSubView.m
//  Stage1st
//
//  Created by hanza on 14-1-21.
//  Copyright (c) 2014年 Renaissance. All rights reserved.
//

#import "S1TopicListCellSubView.h"
#import "S1Topic.h"
#import "Stage1st-Swift.h"

@implementation S1TopicListCellSubView

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self != nil) {
        _highlighted = NO;
        _pinningToTop = NO;
    }
    return self;
}

// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect {
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Color Declarations
    UIColor *cellBackgroundColor = _highlighted ?
    [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.background.highlight"] :
    [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.background.normal"];

    if (_pinningToTop) {
        cellBackgroundColor = _highlighted ?
        [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.pinningTopBackground.highlight"] :
        [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.pinningTopBackground.normal"];
    }

    UIColor *replyCountRectFillColor = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.fill"];
    UIColor *replyCountRectStrokeColor = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.border.normal"];
    UIColor *replyCountRectStrokeColorOfHistoryThread = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.border.history"];
    UIColor *replyCountRectStrokeColorOfFavoriteThread = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.border.favorite"];
    
    UIColor *replyCountTextColor = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.text.normal"];
    UIColor *replyCountTextColorOfHistoryThread = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.text.history"];
    UIColor *replyCountTextColorOfFavoriteThread = [AppEnvironment.current.colorManager colorForKey:@"topiclist.cell.replycount.text.favorite"];

    // Abstracted Attributes
    NSString* textContent = [self.topic.replyCount stringValue];
    
    // Background Drawing
    UIBezierPath* rectanglePath = [UIBezierPath bezierPathWithRect:self.bounds];
    [cellBackgroundColor setFill];
    [rectanglePath fill];
    
    CGRect roundRectangleRect = CGRectZero;
    CGRect replyCountRect = CGRectZero;
    CGRect replyIncrementCountRect = CGRectZero;

    UIUserInterfaceSizeClass horizontalClass = self.traitCollection.horizontalSizeClass;
    switch (horizontalClass) {
    case UIUserInterfaceSizeClassCompact:
        roundRectangleRect = CGRectMake(19, 18, 37, 19);
        roundRectangleRect = CGRectInset(roundRectangleRect, -2, 0);
        replyCountRect = CGRectMake(20, 20, 35, 18);
        replyCountRect = CGRectInset(replyCountRect, -2, 0);
        replyIncrementCountRect = CGRectMake(16, 38, 43, 16);
        break;
    
    default:
        roundRectangleRect = CGRectMake(19+10, 17, 37, 20);
        roundRectangleRect = CGRectInset(roundRectangleRect, -2, 0);
        replyCountRect = CGRectMake(20+10, 19.5, 35, 18);
        replyCountRect = CGRectInset(replyCountRect, -2, 0);
        replyIncrementCountRect = CGRectMake(16+10, 38, 43, 16);
    }

    // Rounded Rectangle Drawing
    UIBezierPath* roundedRectanglePath = [UIBezierPath bezierPathWithRoundedRect:roundRectangleRect cornerRadius:2];
    CGContextSaveGState(context);
    [replyCountRectFillColor setFill];
    [roundedRectanglePath fill];
    CGContextRestoreGState(context);
    if (self.topic.favorite.boolValue) {
        [replyCountRectStrokeColorOfFavoriteThread setStroke];
    } else if (self.topic.lastViewedPosition) {
        [replyCountRectStrokeColorOfHistoryThread setStroke];
    } else {
        [replyCountRectStrokeColor setStroke];
    }
    roundedRectanglePath.lineWidth = 0.8;
    [roundedRectanglePath stroke];

    //// Reply Count Text Drawing
    UIColor *replyCountFinalColor = nil;
    if (self.topic.favorite.boolValue) {
        replyCountFinalColor = replyCountTextColorOfFavoriteThread;
    } else if (self.topic.lastViewedPosition) {
        replyCountFinalColor = replyCountTextColorOfHistoryThread;
    } else {
        replyCountFinalColor = replyCountTextColor;
    }
    NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
    replyCountParagraphStyle.lineBreakMode = NSLineBreakByClipping;
    replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
    [textContent drawInRect:replyCountRect withAttributes:@{
        NSFontAttributeName: [UIFont systemFontOfSize:12.0f],
        NSParagraphStyleAttributeName: replyCountParagraphStyle,
        NSForegroundColorAttributeName: replyCountFinalColor
    }];
    
    // Draw Reply Increment Text
    if (self.topic.lastReplyCount) {
        NSNumber *replyCountChanged = @([self.topic.replyCount longLongValue] - [self.topic.lastReplyCount longLongValue]);
        if ([replyCountChanged longLongValue] > 0) {
            NSString* replyChangeContent = [NSString stringWithFormat:@"+%@", replyCountChanged];
            NSMutableParagraphStyle *replyCountParagraphStyle = [[NSMutableParagraphStyle alloc] init];
            replyCountParagraphStyle.lineBreakMode = NSLineBreakByClipping;
            replyCountParagraphStyle.alignment = NSTextAlignmentCenter;
            [replyChangeContent drawInRect:replyIncrementCountRect withAttributes:@{
                NSFontAttributeName: [UIFont systemFontOfSize:10.0f],
                NSParagraphStyleAttributeName: replyCountParagraphStyle,
                NSForegroundColorAttributeName: replyCountFinalColor
            }];
        }
    }
}

@end
