//
//  MessageEditViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 25/09/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "MessageEditViewController.h"
#import "DetailViewController.h"
#import "OutboxViewController.h"
#import "Message.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "NSString+HTML.h"
#import "TableViewUtilities.h"
#import <QuartzCore/QuartzCore.h>

@implementation MessageEditViewController
{
    BOOL saved_isHeld_state;
}
@synthesize messageTextView;
@synthesize doneButton;
@synthesize cancelButton;
@synthesize quoteButton;
@synthesize message;
@synthesize commentedToMessage;
@synthesize delegate;

+ (UIViewController *)viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    UIViewController *vc;
    if ([identifierComponents[identifierComponents.count-1] isEqualToString:@"messageEditNav"])
        vc = [self newPopupNavigationController];
    else
        vc = [[MessageEditViewController alloc] initWithNibName:@"MessageEditView" bundle:nil];
    return vc;
}

+ (UINavigationController*)newPopupNavigationController
{
    UINavigationController *navigationController = [[UINavigationController alloc] init];
    if( [navigationController respondsToSelector:@selector(restorationIdentifier)] ){
        navigationController.restorationIdentifier = @"messageEditNav";
        navigationController.restorationClass = [MessageEditViewController class];
    }
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    if (@available(iOS 13.0, *)) {
        navigationController.modalInPresentation = true;
        if (![iXolrAppDelegate iPad]) { // don't want "card-style" presentation as it breaks drag-down
            navigationController.modalPresentationStyle = UIModalPresentationFullScreen;
        }
    }
    return navigationController;
}

+ (void)popupMessageEdit:(CIXMessage*)message commentTo:(CIXMessage*)origMessage from:(UIViewController*)from delegate:(id<MessageEditViewControllerDelegate>)delegate {
    MessageEditViewController *messageVC = [[MessageEditViewController alloc] initWithNibName:@"MessageEditView" bundle:nil];
    messageVC.title = [message summary];
    messageVC.message = message;
    messageVC.commentedToMessage = origMessage;
    messageVC.delegate = delegate;
    
    UINavigationController *navigationController = [self newPopupNavigationController];
    [navigationController pushViewController:messageVC animated:NO];
    [from presentViewController:navigationController animated:YES completion:nil];
    
    // The navigation controller is now owned by the current view controller
    // and the new view controller is owned by the navigation controller.
}

// Preserve UI state
- (void) encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    if (self.message != nil)
        [coder encodeObject:self.message.cixLink forKey:@"message"];
    if (self.commentedToMessage != nil)
        [coder encodeObject:self.commentedToMessage.cixLink forKey:@"commentedToMessage"];
    [coder encodeObject:delegate forKey:@"delegate"];
    [coder encodeObject:self.messageTextView.text forKey:@"text"];
}

// Restore UI state
- (void) decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    NSString *msgLink = [coder decodeObjectOfClass:[NSString class] forKey:@"message"];
    self.message = [[iXolrAppDelegate singleton] messageForCIXurl:msgLink];
    if (self.message == nil) {
        NSLog(@"MessageEditViewController:decodeRestorableStateWithCoder - nil message restored.");
    }
    msgLink = [coder decodeObjectOfClass:[NSString class] forKey:@"commentedToMessage"];
    self.commentedToMessage = [[iXolrAppDelegate singleton] messageForCIXurl:msgLink];
    // For NSSecureCoder, we need to list here the classes which are possible delegates.
    delegate = [coder decodeObjectOfClasses:[NSSet setWithObjects: [DetailViewController class], [OutboxViewController class], nil] forKey:@"delegate"];
    self.messageTextView.text = [coder decodeObjectOfClass:[NSString class] forKey:@"text"];
}


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (IBAction)cancelButtonPressed:(id)sender {
    if (messageTextView.delegate != nil) {    // If the delegate is set then the text never changed so cancel straight away
        message.isHeld = saved_isHeld_state;
        [delegate messageEditViewControllerCancelled:self];
    } else {
        [UIAlertController showWithTitle:@"Confirm cancel" message:@"Do you want to cancel this edit and lose any changes made?" actionTitle:@"Lose changes" cancelTitle:@"Keep editing" from:self ifConfirmed:^{
            self->message.isHeld = self->saved_isHeld_state;
            [self->delegate messageEditViewControllerCancelled:self];
        }];
    }
}

- (IBAction)doneButtonPressed:(id)sender {
    message.text = self.messageTextView.text;
    message.isHeld = saved_isHeld_state;
    [delegate messageEditViewControllerConfirmed:self];
}

- (IBAction)quoteButtonPressed:(id)sender {
    [messageTextView insertText: commentedToMessage.textQuoted];
}

// If the user has started to edit the text, we want to flip from quoting allowed to done-button enabled
- (void)textViewDidChange:(UITextView *)textView
{
    if (self.navigationItem.rightBarButtonItem != self.doneButton) {
        self.navigationItem.rightBarButtonItem = self.doneButton;
        [self.navigationItem.titleView sizeToFit];
    }
    messageTextView.delegate = nil; // Not interested in any more callbacks
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.leftBarButtonItem = self.cancelButton;
    if (self.commentedToMessage != nil) 
        self.navigationItem.rightBarButtonItem = self.quoteButton;
    else
        self.navigationItem.rightBarButtonItem = self.doneButton;
    self.messageTextView.text = self.message.text;
    NSRange startRange = {0,0};
    self.messageTextView.selectedRange = startRange;
    [self.messageTextView becomeFirstResponder];

    // register for keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    
    self->saved_isHeld_state = message.isHeld;
    message.isHeld = YES;

    // iOS built-in restoration
    if( [self respondsToSelector:@selector(restorationIdentifier)] ){
        self.restorationIdentifier = @"messageEdit";
        self.restorationClass = self.class;
        self.messageTextView.restorationIdentifier = @"messageEditTextView";
    }
}

+ (UIFont*)pullDownMessageFont
{
    if ([iXolrAppDelegate settings].useDynamicType)
        return [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    else
        return [UIFont systemFontOfSize: [UIFont smallSystemFontSize]];
}

+ (CGRect)pullDownMessageFrame: (CGRect) frame forText: (NSString*)text
{
    // Inset the label and move down to suit the height of text
    CGRect rect = [text boundingRectWithSize:CGSizeMake(frame.size.width, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin attributes:@{NSFontAttributeName: [MessageEditViewController pullDownMessageFont]} context:nil];
    return CGRectMake(5, -rect.size.height, frame.size.width-10, rect.size.height);
}

+ (UILabel*)pullDownMessageLabelWithFrame: (CGRect)frame text: (NSString*)text
{
    text = [iXolrAppDelegate settings].reflowText ? [text stringWithReflow] : text;
    text = [text stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
    UILabel *commentToLabel = [[UILabel alloc] initWithFrame:[MessageEditViewController pullDownMessageFrame:frame forText:text]];
    commentToLabel.numberOfLines = 0;
    commentToLabel.lineBreakMode = NSLineBreakByWordWrapping;
    commentToLabel.font = [MessageEditViewController pullDownMessageFont];
    commentToLabel.backgroundColor = [UIColor colorWithRed:0.4 green:0.4 blue:0.9 alpha:0];
    commentToLabel.shadowOffset = CGSizeMake(0, -1);
    commentToLabel.textColor = [UIColor whiteColor];
    commentToLabel.shadowColor = [UIColor darkGrayColor];
    commentToLabel.text = text;
    return commentToLabel;
}

+ (CALayer*)pullDownMessageGradientWithFrame: (CGRect)frame 
{
    // Smooth-shaded gradient background for the text
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = frame;
    UIColor *topColour = [UIColor colorWithRed:0.5 green:0.5 blue:1 alpha:1.0];
    UIColor *botColour = [UIColor colorWithRed:0.5 green:0.4 blue:0.7 alpha:1.0];
    gradient.colors = @[(id)[topColour CGColor], (id)[botColour CGColor]];
    return gradient;
}

- (void)viewWillAppear:(BOOL)animated
{
    //NSLog(@"MessageEdit viewWillAppear");
    self.title = [message summary];
    if (![iXolrAppDelegate iPad]) { // Create a label for the title so we can set adjustsFontSizeToFitWidth
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 480, 44)];
        label.backgroundColor = [UIColor clearColor];
        label.font = [UIFont boldSystemFontOfSize: 18.0f];
        label.adjustsFontSizeToFitWidth = YES;
        label.minimumScaleFactor = 0.5;
        label.textAlignment = NSTextAlignmentCenter;
        label.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        label.textColor = [UIColor darkTextColor];
        label.text = self.title;
        
        self.navigationItem.titleView = label;
        
    } else
        self.navigationItem.title = self.title;

    if (self.commentedToMessage != nil)
    {   // Show the message that this is a comment to in a label that will appear if the view is dragged down
        UIView *commentToLabel = [MessageEditViewController pullDownMessageLabelWithFrame:self.messageTextView.frame text:commentedToMessage.text];
        [self.messageTextView addSubview:commentToLabel];
        self.messageTextView.alwaysBounceVertical = YES;
        if (@available(iOS 13.0, *)) {
            // Stop the nav-bar being translucent.
            self.navigationController.navigationBar.scrollEdgeAppearance = [[UINavigationBarAppearance alloc] init];
        }
        [self.messageTextView.layer insertSublayer:[MessageEditViewController pullDownMessageGradientWithFrame:commentToLabel.frame] below:commentToLabel.layer];
    }
    [super viewWillAppear: animated];
}

#pragma mark - Keyboard handling

// Called when the UIKeyboardDidShowNotification is sent.
// Shrink the height of the text edit view so it's not partially hidden by the keyboard
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    CGRect kbRect = [[aNotification userInfo][UIKeyboardFrameEndUserInfoKey] CGRectValue];
    // Rotate keyboard coordinates to coordinate system of this view
    kbRect = [self.view convertRect:kbRect fromView:nil];
    CGRect myFrame = messageTextView.frame;
    myFrame.size.height = kbRect.origin.y;
    messageTextView.frame = myFrame;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    messageTextView.frame = self.view.frame;
}
@end
