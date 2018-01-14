//
//  MessageEditViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 25/09/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol MessageEditViewControllerDelegate;
@class CIXMessage;

@interface MessageEditViewController : UIViewController <UITextViewDelegate, UIViewControllerRestoration>

+ (void)popupMessageEdit:(CIXMessage*)message commentTo:(CIXMessage*)origMessage from:(UIViewController*)from delegate:(id<MessageEditViewControllerDelegate>)delegate;

// Helper functions to create a view showing previous message
+ (UILabel*)pullDownMessageLabelWithFrame: (CGRect)frame text: (NSString*)text;
+ (CALayer*)pullDownMessageGradientWithFrame: (CGRect)frame;
+ (CGRect)pullDownMessageFrame: (CGRect) frame forText: (NSString*)text;

@property (nonatomic, weak) id <MessageEditViewControllerDelegate> delegate;
@property (nonatomic, strong) CIXMessage *message;
@property (nonatomic, strong) CIXMessage *commentedToMessage;
@property (nonatomic, strong) IBOutlet UITextView *messageTextView;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *doneButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *quoteButton;

@end

@protocol MessageEditViewControllerDelegate
- (void)messageEditViewControllerConfirmed:(MessageEditViewController *)controller;
- (void)messageEditViewControllerCancelled:(MessageEditViewController *)controller;
@end
