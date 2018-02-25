//
//  DetailViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "DetailViewController.h"
#import "iXolrAppDelegate.h"
#import "Topic.h"
#import "Conference.h"
#import "Message.h"
#import "TopSettingsVC.h"
#import "DataController.h"
#import "TableViewUtilities.h"
#import "ActivityProviders.h"
#import "NSString+HTML.h"

// Special override for one method so the keyboard goes away when you do a search in the CIX conference directory
@interface UINavigationController (KeyboardDismiss)
- (BOOL)disablesAutomaticKeyboardDismissal;
@end

@implementation UINavigationController(KeyboardDismiss)
- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}
@end

@implementation DetailViewController {
@private
    BOOL _observingCurrentMessage;
    BOOL _viewHasLoaded;
    ThreadedMessageListVC *_messageTableController;
}

@synthesize topic=_topic;
@synthesize toolbar=_toolbar;
@synthesize currentMessage=_currentMessage;

@synthesize textWebView=_textWebView;
@synthesize messageTableView=_messageTableView;
@synthesize toolbarTitle = _toolbarTitle;
@synthesize searchBar = _searchBar;
@synthesize lowerView = _lowerView;
@synthesize headerView = _headerView;
@synthesize headerLabel = _headerLabel;
@synthesize starButton = _starButton;
@synthesize editButton = _editButton;
@synthesize lockButton = _lockButton;
@synthesize pullDownMessageLabel = _pullDownMessageLabel;
@synthesize actionBarButtonItem = _actionBarButtonItem;

+ (DetailViewController *) findDetailViewFrom: (UIStoryboardSegue *)segue
{
    // We get different objects passed depending on iOS 7 vs 8, iPad/iPhone6+, maybe other things
    NSObject *destinationViewController = segue.destinationViewController;
    if ([destinationViewController isKindOfClass:[DetailViewController class]])
        return (DetailViewController*)destinationViewController;
    else if ([destinationViewController isKindOfClass:[UINavigationController class]])
        return (DetailViewController *)[(UINavigationController*)destinationViewController topViewController];
    else
        NSLog(@"Unexpected destination of segue %@: %@", segue, destinationViewController);
    return nil;
}

// Preserve UI state
- (void) encodeRestorableStateWithCoder:(NSCoder *)coder {
    [super encodeRestorableStateWithCoder:coder];
    [self.messageTableController encodeRestorableStateWithCoder:coder];
    if (self.currentMessage != nil)
        [coder encodeInt:self.currentMessage.msgnum_int forKey:@"msgnum"];
}

// Restore UI state
- (void) decodeRestorableStateWithCoder:(NSCoder *)coder {
    [super decodeRestorableStateWithCoder:coder];
    NSString *confname = [iXolrAppDelegate singleton].currentConferenceName;
    if (confname != nil) {
        NSString *topicname = [iXolrAppDelegate singleton].currentTopicName;
        Topic *topic = [[iXolrAppDelegate singleton].dataController findOrCreateConference:confname Topic:topicname];
        [self setTopic:topic];
        [self.messageTableController decodeRestorableStateWithCoder:coder];
        if ([coder containsValueForKey:@"msgnum"]) {
            int msgnum = [coder decodeIntForKey:@"msgnum"];
            CIXMessage *message = [topic messageWithNumber:msgnum];
            [self showMessageDetail:message movingBack:NO];
        }
    }
}

// Create messageTableController on demand
- (ThreadedMessageListVC *)messageTableController
{
    if (_messageTableController == nil) {
        _messageTableController = [[ThreadedMessageListVC alloc] init];
        _messageTableController.delegate = self;
    }
    return _messageTableController;
}

- (void) awakeFromNib{
    // Set property so top-level can control us.  Should really be a push/pop operation.
    [iXolrAppDelegate singleton].detailViewController = self;
    [super awakeFromNib];
}

#pragma mark - Managing topic and message in view

- (void)setTopic:(Topic *)object
{
	if (_topic != object) {
		_topic = object;

        // Read all the messages in and thread them.
        [self.messageTableController configureView:self.topic withReload:YES];
        
        // Let the user see where we are in the toolbar title
        self.toolbarTitle.text = [iXolrAppDelegate iPad] ? _topic.fullName : _topic.name;
        [[NSNotificationCenter defaultCenter] postNotificationName:@"currentTopicChanged" object:_topic];
    }
}

// msgnum is specific message to go to, or 0 for first unread, or -1 for first priority message
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum
{
    if (self.topic != topic && topic != nil) {  // nil topic means stay on current topic
        [self setTopic:topic];
        if (msgnum == 0)
            // When we move to a new topic we go to the first unread message (?)
            if (_topic.messagesUnreadCount > 0)
                [self moveToFirstUnreadMessage];
            else
                [self showMessageDetail: nil movingBack:NO];  // No current message
    }
    if (msgnum == -1) {
        id nextMessage = [self.messageTableController nextInteresting];
        if (nextMessage == nil)
            nextMessage = [self.messageTableController firstInteresting];
        if (nextMessage != nil)
            [self moveToDisplayMessage: nextMessage movingBack:NO];
    }
    if (msgnum > 0) 
        [self moveToDisplayMessageNumber:msgnum];
}

- (NSString*)totalUnreadDisplay
{
    NSInteger totalUnread = [iXolrAppDelegate singleton].dataController.countOfUnread;
    return [NSString stringWithFormat:@"CIX (%ld)", (long)totalUnread];
}

// Callback from key-value observing - something has changed...
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqual:@"text"]) {
        if (object == self.currentMessage)
            [self showMessageDetail:self.currentMessage movingBack:YES];
        [self.messageTableController forceRedrawOfMessage:self.currentMessage];
    } else if ([keyPath isEqualToString:@"countOfUnread"]) {
        if (self.navigationItem.leftBarButtonItem.title != nil) {
            self.navigationItem.leftBarButtonItem.title = [self totalUnreadDisplay];
        }
    } else if ([keyPath isEqualToString:@"countOfInteresting"]) {
        [self adjustPriorityMessageButtons];
    }
}

- (void)adjustPriorityMessageButtons
{
    NSInteger totalInteresting = [iXolrAppDelegate singleton].dataController.countOfInteresting;
    // want button enabled if there is another interesting/priority message to jump to
    BOOL buttonEnabled = (totalInteresting > 1) || (totalInteresting == 1 && !(self.currentMessage.isInteresting && !self.currentMessage.isRead));
    self.fastForwardButtonItem.enabled = buttonEnabled;
    self.fastForwardButton.enabled = buttonEnabled;
}

// Notification has arrived of new messages in one topic; see if anything needs to be added to the thread view
- (void)handleChangedMessagesInTopic:(NSNotification*)param
{
    if (self.topic == [param object]) {
        [self.messageTableController handleChangedMessagesInTopic:self.topic];
        if (self.currentMessage != nil) {
            // See if the message number is still there but changed object
            NSObject<GenericMessage>* msg = [self.topic messageWithNumber:self.currentMessage.msgnum_int];
            if (self.currentMessage != msg) {
                [self showMessageDetail: msg movingBack:YES];   // Redisplay new or blank message (showMessageDetail will set currentMessage)
            }
            if (self.currentMessage != nil)
                [self moveToDisplayMessage:self.currentMessage movingBack:YES];
        }
    }
}

// We have been told that the read count in a topic has changed, either for a single object
// or because someone has done something like 'mark all read'.  Repaint all rows and update thread headers in the latter case.
- (void)handleMessageReadCountChanged:(NSNotification*)param
{
    Topic *topic = [param object];
    if (topic == self.topic) {
        id<GenericMessage> message = [param userInfo][@"SingleMessage"];
        if (message != nil)
            [self.messageTableController handleMessageReadCountChanged:message];
        else     // message is nil -> not a specific message that changed -> redraw everything
            [self.messageTableController redrawAllVisibleRows];
    }
}

- (void)userTextSizeDidChange
{
    [self.messageTableController userTextSizeDidChange];
    [self showMessageDetail:self.currentMessage movingBack:YES];
}

- (void)handleMessageSettingsChanged:(NSNotification*)param
{
    // Redraw the message text because something like the font has changed
    [self showMessageDetail:self.currentMessage movingBack:YES];
}

- (void)handleThreadSettingsChanged:(NSNotification*)param
{
    // Redraw the thread table because something like the font has changed
    [self.messageTableController configureThreadsWithReload:YES];
}

// Notification that one or more messages are about to be deleted.  If param.object is non-nil, just that one message is being deleted.
- (void)handleMessageDelete:(NSNotification*)param
{
    if (param.object == nil)
        [lastVisited removeAllObjects];
    else
        [lastVisited removeObject:[param object]];
}

- (void)markMessageRead:(id<GenericMessage>)message status: (BOOL)value
{
    if (message.isRead == !value)
    {
        message.isRead = value;
        [message.topic messageReadStatusChanged:message];
    }
}

- (void)showMessageFlags:(NSObject<GenericMessage>*)message {
    [self.starButton setTitle: message.isFavourite ? @"★" : @"☆" forState:UIControlStateNormal];
    [self.starButton setTitleColor:message.isFavourite ? [UIColor yellowColor] : [UIColor colorWithWhite:0.9 alpha:1.0] forState:UIControlStateNormal];
    [self.starButton setHidden: message == nil || message.isOutboxMessage];    
    [self.editButton setHidden: message == nil || !message.isOutboxMessage];
    if (message.isOutboxMessage)
        [self.lockButton setImage: message.isHeld ? [UIImage imageNamed:@"lock.png"] : [UIImage imageNamed:@"lock-outline.png"] forState:UIControlStateNormal];
    [self.lockButton setHidden: message == nil || !message.isOutboxMessage];
}

- (NSString*)getHTMLforMessage: (NSObject<GenericMessage>*)message
{
    float textSize = [iXolrAppDelegate settings].useDynamicType ? 0 : [iXolrAppDelegate settings].messageFontSize;
    return [message textAsHTMLwithSize:textSize reflow:[iXolrAppDelegate settings].reflowText forWidth:self.textWebView.frame.size.width-16 inlineImages:[iXolrAppDelegate settings].inlineImages];
}

- (void)setUpPulldownView: (id<GenericMessage>) commentedToMessage
{
    if (commentedToMessage != nil && ![commentedToMessage isPlaceholder])
    {   // Show the message that this is a comment to in a label that will appear if the view is dragged down
        if (self.pullDownMessageLabel == nil) {
            CGRect frame = CGRectMake(0, -250, self.textWebView.frame.size.width, 250);
            self.pullDownMessageLabel = [MessageEditViewController pullDownMessageLabelWithFrame:frame text:@""];
            [self.textWebView.scrollView addSubview:self.pullDownMessageLabel];
            [self.textWebView.scrollView.layer insertSublayer:[MessageEditViewController pullDownMessageGradientWithFrame:frame] below:self.pullDownMessageLabel.layer];
        }
        // Inset the label and move down to suit the height of text
        NSString *text = commentedToMessage.text;
        text = [iXolrAppDelegate settings].reflowText ? [text stringWithReflow] : text;
        self.pullDownMessageLabel.frame = [MessageEditViewController pullDownMessageFrame:self.textWebView.frame forText:text];
        self.pullDownMessageLabel.text = text;
    }
    else if (self.pullDownMessageLabel != nil)
        self.pullDownMessageLabel.text = @"";
}

// Work round bug in iOS 9 where UIWebView internal class UIWebBrowserView gets an ever-increasing list of _UITextSelectionForceGesture
// Since mentioning an internal class will get the app rejected from the App Store, recurse over overy subview
// and blindly truncate any view with an excessive list.
void fixGestureRecognizers(UIView *v) {
    const int maxRecognizers=12;
    if (v.gestureRecognizers.count > maxRecognizers) {
        //NSLog(@"%@: %d", v.class, v.gestureRecognizers.count);
        //for (UIGestureRecognizer* g in v.gestureRecognizers)
        //    NSLog(@"%@", g);
        NSMutableArray* a = [NSMutableArray arrayWithCapacity:maxRecognizers];
        for (int i = 0; i < maxRecognizers; ++i)
            a[i] = v.gestureRecognizers[i];
        v.gestureRecognizers = a;
    }
    for (UIView* c in v.subviews) {
        fixGestureRecognizers(c);
    }
}

// Set up the detail view to show the given message, and remember where we've been so we can go back
- (void)showMessageDetail:(NSObject<GenericMessage>*)message movingBack:(BOOL)back
{
    // Deal with the previous message
    if (!back && self.currentMessage != nil && !self.currentMessage.isPlaceholder) {
        [lastVisited addObject:self.currentMessage];
    }
    if (_observingCurrentMessage)
        [self.currentMessage removeObserver:self forKeyPath:@"text"];
    _observingCurrentMessage = FALSE;
    self.currentMessage = message;
    if (!_viewHasLoaded)
        return;
    if (message == nil)
    {
        self.headerLabel.text = @"";
        [self.textWebView loadHTMLString:@"" baseURL:nil];
    }
    else
    {
        self.headerLabel.text = message.headerLine;
        [self.textWebView loadHTMLString: [self getHTMLforMessage:message] baseURL:nil];
        fixGestureRecognizers(self.textWebView);
        [self performSelector:@selector(flashScrollbarsIfNecessary) withObject:nil afterDelay:0.1]; // do this after display has recalculated
        [self setUpPulldownView: [self currentMessageOriginal]];
        [message addObserver:self forKeyPath:@"text" options:0 context:nil];
        _observingCurrentMessage = TRUE;
    }
    [self showMessageFlags:message];
    [self adjustPriorityMessageButtons];
//    if (message.indentTransient + threadIndentAdjustment < 0)
//        [self adjustThreadIndent];
}

- (void)flashScrollbarsIfNecessary
{
    if (self.textWebView.scrollView.contentSize.height > self.textWebView.scrollView.frame.size.height)
        [self.textWebView.scrollView flashScrollIndicators];
}

- (void)animateButtonsToAlpha: (CGFloat)alpha duration: (CGFloat)duration
{
    [UIView animateWithDuration:duration animations: ^ {
        [self.lowerView viewWithTag:1].alpha = alpha;
        [self.lowerView viewWithTag:2].alpha = alpha;
        [self.lowerView viewWithTag:3].alpha = alpha;
        [self.lowerView viewWithTag:4].alpha = alpha;
    } completion: ^(BOOL finished) {
        [self.lowerView viewWithTag:1].layer.shadowOpacity = alpha / 2;
        [self.lowerView viewWithTag:2].layer.shadowOpacity = alpha / 2;
        [self.lowerView viewWithTag:3].layer.shadowOpacity = alpha / 2;
        [self.lowerView viewWithTag:4].layer.shadowOpacity = alpha / 2;
    } ];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    // Set property so top-level can control us.  Should really be a push/pop operation.
    [iXolrAppDelegate singleton].detailViewController = self;
    if (!_observingCurrentMessage)
        [self.currentMessage addObserver:self forKeyPath:@"text" options:0 context:nil];
    _observingCurrentMessage = TRUE;
    
    if (![iXolrAppDelegate settings].showMessageToolbar) {
        [[self navigationController] setToolbarHidden:YES animated:NO];
    }

    // Move header bar to where we left it last time
    if ([iXolrAppDelegate singleton].threadWindowSize != 0)
        [self positionHeaderAtYCoord:[iXolrAppDelegate singleton].threadWindowSize * self.view.frame.size.height];

    if (self.topic != nil)
        [self.messageTableController configureView:self.topic withReload:NO];
    
    // Set up the message and flags display
    if (self.currentMessage != nil) {
        [self moveToDisplayMessage:self.currentMessage movingBack:NO];
    }
    [self showMessageDetail:self.currentMessage movingBack:NO];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    if (![iXolrAppDelegate iPad])
        [self animateButtonsToAlpha:0.05 duration:0.9];

    hasAppeared = YES;
}

- (void)viewWillDisappear:(BOOL)animated
{
    if (_observingCurrentMessage)
        [self.currentMessage removeObserver:self forKeyPath:@"text"];
    _observingCurrentMessage = FALSE;
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
    
    // Clear property so top-level stops controlling us.  Should really be a push/pop operation.
    [iXolrAppDelegate singleton].detailViewController = nil;
    if (![iXolrAppDelegate iPad])
        [self removeSearchBar];
    hasAppeared = NO;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
    [self showMessageDetail:self.currentMessage movingBack:NO];
}

// Move the header bar to a specific y-coord, repositioning anything else that needs moved to suit
- (void)positionHeaderAtYCoord: (CGFloat)y
{
    self.messageTableViewHeight.constant = y;
    [self.view layoutIfNeeded];
}

// Remove action button on iPhone - it doesn't fit
- (void)setiPhoneRightBarButton
{
    NSMutableArray *buttons = [self.navigationItem.rightBarButtonItems mutableCopy];
    [buttons removeObject:self.actionBarButtonItem];
    [self.navigationItem setRightBarButtonItems: buttons animated:NO];
}

- (void)viewDidLoad
{
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedMessagesInTopic:) name:@"changedMessagesInTopic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageDelete:) name:@"willDeleteMessage" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageSettingsChanged:) name:@"messageSettingsChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleThreadSettingsChanged:) name:@"threadSettingsChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageReadCountChanged:) name:@"messageReadCountChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(userTextSizeDidChange) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"countOfUnread" options:NSKeyValueObservingOptionInitial context:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"countOfInteresting" options:NSKeyValueObservingOptionInitial context:nil];
    [super viewDidLoad];

    if ([iXolrAppDelegate settings].showMessageToolbar) {
        // Hide magic buttons
        for (int i = 1; i <= 4; ++i)
            [self.lowerView viewWithTag:i].hidden = YES;
    }
    if (![iXolrAppDelegate iPad]) {
        [self setiPhoneRightBarButton];
        // If toolbar is visible, put the buttons in place
        if (![iXolrAppDelegate settings].showMessageToolbar) {
            [((UIButton*)[self.lowerView viewWithTag:1]) setTitle: @"Next" forState:UIControlStateNormal];
            [((UIButton*)[self.lowerView viewWithTag:2]) setTitle: @"Last" forState:UIControlStateNormal];
            [((UIButton*)[self.lowerView viewWithTag:3]) setTitle: @"Orig" forState:UIControlStateNormal];
            [self.lowerView viewWithTag:4].hidden = YES;  // Don't show 'next priority' button on iPhone because there isn't really room for it
            [[self navigationController] setToolbarHidden:YES animated:NO];
            // Set up shadows on navigation 'magic buttons' in iPhone version
            for (int i = 1; i <= 4; ++i)
                [self.lowerView viewWithTag:i].layer.shadowRadius = 2.0;
            // Create a  gesture recognizer to recognize taps in the message view to show and hide the magic buttons.
            UIGestureRecognizer *recognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onTapInWebView:)];
            recognizer.delegate = self;
            [self.textWebView addGestureRecognizer:recognizer];
        }
        // Remove the search bar in the title bar
        [self removeSearchBar];
    }
    else {
        self.toolbar.delegate = self;
    }
    
    self.textWebView.scrollView.decelerationRate = UIScrollViewDecelerationRateNormal;
    self.textWebView.scrollView.scrollsToTop = NO;  // Leave message list as the sole scrollview that will scroll to top on tap on status bar
    self.textWebView.delegate = self;
    self.textWebView.allowsLinkPreview = YES;
    lastVisited = [[NSMutableArray alloc] initWithCapacity:10];

    self.headerView.backgroundColor = [self.view tintColor];

    _viewHasLoaded = YES;
    self.messageTableController.messageTableView = self.messageTableView;
}

- (UIBarPosition)positionForBar:(id <UIBarPositioning>)bar {
    return UIBarPositionTopAttached;
}

- (void)viewDidUnload
{
    [iXolrAppDelegate singleton].detailViewController = nil;
    [self setSearchBar:nil];
    [self setHeaderLabel:nil];
    [self setHeaderView:nil];
    [self setLowerView:nil];
    [self setStarButton:nil];
    [self setEditButton:nil];
    [self setLockButton:nil];
    [self setActionBarButtonItem:nil];
    [self setFastForwardButtonItem:nil];
	[super viewDidUnload];

	// Release any retained subviews of the main view.
    self.messageTableView = nil;
    self.textWebView.delegate = nil;
    self.textWebView = nil;
    self.pullDownMessageLabel = nil;
    self.toolbarTitle = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    lastVisited = nil;
}

#pragma mark - Web View Delegate

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    // Redirect http and mail links to Safari and Mail
    if (navigationType == UIWebViewNavigationTypeLinkClicked)
    {
        [[UIApplication sharedApplication] openURL:[request URL]];
        return NO;
    }
    return YES;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc
{
    if (_viewHasLoaded) {
        [[NSNotificationCenter defaultCenter] removeObserver:self];
        [[iXolrAppDelegate singleton].dataController removeObserver:self forKeyPath:@"countOfUnread"];
        [[iXolrAppDelegate singleton].dataController removeObserver:self forKeyPath:@"countOfInteresting"];
    }
    if (_observingCurrentMessage)
        [self.currentMessage removeObserver:self forKeyPath:@"text"];
}

#pragma mark - Toolbar actions

- (IBAction)popupNewMessageEditCommentTo:(CIXMessage*)origMessage {
    if (self.topic.isReadOnly) {
        NSString *str = [NSString stringWithFormat:@"Topic %@ is read-only; are you sure you want to post?", self.topic.fullName];
        [UIAlertView showWithTitle:@"Read-only Topic" message:str completionBlock:^(NSUInteger buttonIndex) {
            if (buttonIndex == 1)
                [self reallyPopupNewMessageEditCommentTo:origMessage];
        } cancelButtonTitle:@"Cancel" otherButtonTitles:@"Continue", nil];
    } else if ([self.topic.conference.name isEqualToString:@"noticeboard"] && origMessage != nil) {
        NSString *str = [NSString stringWithFormat:@"Comments are forbidden in cix:noticeboard; are you sure you want to post?"];
        [UIAlertView showWithTitle:@"Comment in Noticeboard" message:str completionBlock:^(NSUInteger buttonIndex) {
            if (buttonIndex == 1)
                [self reallyPopupNewMessageEditCommentTo:origMessage];
            else if (buttonIndex == 2)
                [self replyViaEmailTo:origMessage];
        } cancelButtonTitle:@"Cancel" otherButtonTitles:@"Continue", @"Use email instead", nil];
    } else
        [self reallyPopupNewMessageEditCommentTo:origMessage];
}

- (IBAction)reallyPopupNewMessageEditCommentTo:(CIXMessage*)origMessage {
    // Create a new message object to edit
    CIXMessage *message = [[iXolrAppDelegate singleton].dataController createNewOutboxMessage:origMessage topic:self.topic];
    if ([iXolrAppDelegate settings].signature == nil)
        message.text = @"";
    else
        message.text = [NSString stringWithFormat:@"\n\n%@", [iXolrAppDelegate settings].signature];

    [MessageEditViewController popupMessageEdit:message commentTo:origMessage from:self delegate:self];
}

- (void)replyViaEmailTo:(CIXMessage*)message
{
    if([MFMailComposeViewController canSendMail]) {
            NSString* emailAddress = [NSString stringWithFormat:@"%@@cix.co.uk", message.author];
            MFMailComposeViewController *mailCont = [[MFMailComposeViewController alloc] init];
            mailCont.mailComposeDelegate = self;
            
            [mailCont setSubject:[NSString stringWithFormat:@"Re: %@", message.cixLink]];
            [mailCont setToRecipients:@[emailAddress]];
            [mailCont setMessageBody:message.textQuoted isHTML:NO];
            
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self presentViewController:mailCont animated:YES completion:nil];
            }];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Unable to send email" message:@"You must have email configured on this device in order to send a reply via email." delegate:nil cancelButtonTitle:@"Cancel" otherButtonTitles:nil];
        [alert show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    // Run on main thread in case this gets called on different thread
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self dismissViewControllerAnimated:YES completion:nil];
    }];
}

- (IBAction)settingsButtonPressed:(id)sender {
    // currently displaying actionsheet?
    if (_actionSheet || _activityPopover)
        [self popdownActionSheet];
    
    TopSettingsVC *settingsVC = [[TopSettingsVC alloc] initWithNibName:@"TopSettings" bundle:nil];
    settingsVC.delegate = self;
    // Create the navigation controller and present it modally.
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:settingsVC];
    navigationController.modalPresentationStyle = UIModalPresentationFormSheet;
    [self presentViewController:navigationController animated:YES completion:nil];
    
    // The navigation controller is now owned by the current view controller
    // and the new view controller is owned by the navigation controller.
}

- (void)settingsViewControllerFinished:(TopSettingsVC *)controller
{
    [[iXolrAppDelegate singleton] saveState];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void) popdownActionSheet {
    if (_actionSheet) {
        [_actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        _actionSheet = nil;
    }
    if (_activityPopover) {
        [_activityPopover dismissPopoverAnimated:YES];
        _activityPopover = nil;
    }
}

-(void)popupReplyActionSheet:(id)sender withShare:(BOOL)withShare {
    _actionSheet = [[UIActionSheet alloc] initWithTitle:@"Actions" completionBlock:nil cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
    NSInteger replyCIX=-1, replyEmail=-1, share=-1, startThread=-1;
    if (self.topic == nil)
        _actionSheet.title = @"No actions";
    else {
        if (self.currentMessage != nil && !self.currentMessage.isOutboxMessage && !self.currentMessage.isPlaceholder) { // Check it's not an outbox message - no actions allowed on those
            replyCIX = [_actionSheet addButtonWithTitle:@"Reply via CIX"];
            replyEmail = [_actionSheet addButtonWithTitle:@"Reply via email"];
            if (withShare)
                share = [_actionSheet addButtonWithTitle:@"Share..."];
        }
        startThread = [_actionSheet addButtonWithTitle:@"Start new thread"];
    }

    _actionSheet.cancelButtonIndex = [_actionSheet addButtonWithTitle:@"Cancel"];

    DetailViewController * __weak weakSelf = self;
    [_actionSheet setCompletionBlock:^(NSInteger buttonIndex) {
        DetailViewController *vc = weakSelf;
        if (vc == nil)
            return;
        NSInteger cancelButtonIndex = vc->_actionSheet.cancelButtonIndex;
        vc->_actionSheet = nil;
        
        id<GenericMessage> msg = vc.currentMessage;
        if (buttonIndex == -1 || buttonIndex == cancelButtonIndex)
            ;   // Do nothing
        else if (buttonIndex == startThread)
            [vc popupNewMessageEditCommentTo:nil];
        else if (buttonIndex == replyCIX)
            [vc popupNewMessageEditCommentTo:(CIXMessage*) msg];     // Can cast because we know it's not a placeholder per the above test
        else if (buttonIndex == replyEmail)
            [vc replyViaEmailTo:(CIXMessage*)msg];
        else if (buttonIndex == share)
            [vc popupActivitySheetFrom:sender];
    }];
    [_actionSheet showFromBarButtonItem:sender animated:YES];
}

- (void)popupActivitySheetFrom:(id)sender {
    id<GenericMessage> msg = self.currentMessage;
    if (msg != nil && !msg.isPlaceholder) {
        NSString *quote = [NSString stringWithFormat:@"In message %@, %@ wrote:\n%@", msg.cixLink, msg.author, msg.textQuoted];
        NSArray *activityItems = @[msg,quote];
        CopyCixLinkActivity *act = [[CopyCixLinkActivity alloc] init];
        
        UIActivityViewController *activityViewController = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:@[act]];
        
        //activityViewController.excludedActivityTypes = @[UIActivityTypePostToWeibo, UIActivityTypeAssignToContact ];
        
        if ([iXolrAppDelegate iPad]) {
            _activityPopover = [[UIPopoverController alloc] initWithContentViewController:activityViewController];
            [_activityPopover presentPopoverFromBarButtonItem:sender permittedArrowDirections:UIPopoverArrowDirectionUp animated:YES];
        } else {
            [self presentViewController:activityViewController animated:YES completion:NULL];
        }
    }
}

- (IBAction)replyButtonPressed:(id)sender {
    // currently displaying actionsheet?
    if (_actionSheet || _activityPopover) {
        [self popdownActionSheet];
        return;
    }
    [self popupReplyActionSheet:sender withShare:![iXolrAppDelegate iPad]];
}

- (IBAction)actionButtonPressed:(id)sender {
    if (_actionSheet || _activityPopover) {
        [self popdownActionSheet];
        return;
    }
    if ([iXolrAppDelegate iPad])
        [self popupActivitySheetFrom:sender];
    else
        [self popupReplyActionSheet:sender withShare:YES];
}

- (IBAction)onTapInMessageHeader:(UIGestureRecognizer *)recognizer {
    //NSLog(@"Tap");
    if (self.currentMessage == nil || self.currentMessage.isOutboxMessage)  // no actions allowed on outbox message
        return;
    
    [self popupMessageActionSheet:recognizer.view];
}

-(void)popupMessageActionSheet:(id)sender {
    if (self.currentMessage == nil)
        return;
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:@"Message Actions" completionBlock:nil
        cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles: nil];
    _actionSheet = actionSheet;
    NSInteger withdraw=-1, markRead=-1, markPriority=-1, markIgnored=-1, downloadMessage=-1, cixLink=-1, backFill=-1;
    if (self.currentMessage.isPlaceholder) {
        downloadMessage = [actionSheet addButtonWithTitle:@"Download message"];
        backFill = [actionSheet addButtonWithTitle:@"Back-fill thread"];
    } else {
        withdraw     = [actionSheet addButtonWithTitle: @"Withdraw message"];
        markRead     = [actionSheet addButtonWithTitle: self.currentMessage.isRead ? @"Mark unread" : @"Mark read"];
        markPriority = [actionSheet addButtonWithTitle: self.currentMessage.isInteresting ? @"Clear priority" : @"Mark priority"];
        markIgnored  = [actionSheet addButtonWithTitle: self.currentMessage.isIgnored ? @"Clear Ignore flag" : @"Mark ignored"];
        cixLink      = [actionSheet addButtonWithTitle: @"Copy cix: link"];
        if ([self currentMessageOriginal].isPlaceholder)
            backFill = [actionSheet addButtonWithTitle:@"Back-fill thread"];
    }
    actionSheet.cancelButtonIndex = [actionSheet addButtonWithTitle:@"Cancel"];
    [actionSheet setCompletionBlock:^(NSInteger buttonIndex) {
        _actionSheet = nil;
        id<GenericMessage> msg = self.currentMessage;
        
        if (buttonIndex == -1 || buttonIndex == actionSheet.cancelButtonIndex)
            ;   // Do nothing
        else if (buttonIndex == markRead)
            [self markMessageRead:self.currentMessage status:!self.currentMessage.isRead ];
        else if (buttonIndex == markPriority)
            [self.messageTableController markSubthreadPriority:(CIXMessage*)msg status:!msg.isInteresting ];
        else if (buttonIndex == markIgnored)
            [self.messageTableController markSubthreadIgnored:(CIXMessage*)msg status:!msg.isIgnored ];
        else if (buttonIndex == cixLink)      // Copy CIX Link
            [UIPasteboard generalPasteboard].string = msg.cixLink;
        else if (buttonIndex == downloadMessage)
            [[iXolrAppDelegate singleton] downloadMessages:@[@(msg.msgnum_int)] conf:msg.topic.conference.name topic:msg.topic.name];
        else if (buttonIndex == backFill)
            [[iXolrAppDelegate singleton] backfillThread:msg.msgnum_int conf:msg.topic.conference.name topic:msg.topic.name];
        else if (buttonIndex == withdraw)
            [[iXolrAppDelegate singleton] withdrawMessage:(CIXMessage*)msg];
    }];

    if ([sender isKindOfClass:[UIBarButtonItem class]])
        [actionSheet showFromBarButtonItem:sender animated:YES];
    else
        [actionSheet showFromRect:[sender frame] inView:sender animated:YES];
}

// Callback from message edit window
- (void)messageEditViewControllerConfirmed:(MessageEditViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    controller.message.date = [NSDate date];   // get the time now
    [[iXolrAppDelegate singleton].dataController addOutboxMessagesObject:controller.message];
    [[iXolrAppDelegate singleton].dataController saveContext];  // Commit to database
    [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:controller.message.topic];
    if (controller.commentedToMessage != nil)
        [self markMessageRead:controller.commentedToMessage status: YES];
    if (self.currentMessage == controller.message)
        [self showMessageDetail:controller.message movingBack:NO];
    else
        [self moveToDisplayMessage:controller.message movingBack:NO];
    [self.messageTableController forceRedrawOfMessage:controller.message];
}

- (void)messageEditViewControllerCancelled:(MessageEditViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    CIXMessage *tmpMessage = controller.message;
    controller.message = nil;   // Knock out the retained message so it doesn't get released after we delete the message
    if (tmpMessage.date == nil) // Date will be nil for a brand-new message; if user cancels that then get rid of it 
        [[iXolrAppDelegate singleton].dataController deleteMessage:tmpMessage];
}

// Search button is only present on iPhone, thus this code only executes on iPhone
- (IBAction)searchButtonPressed: (id)sender
{
    // Find the topmost UINavigationController
    UINavigationController *nc = self.navigationController;
    while (nc.navigationController != nil)
        nc = nc.navigationController;
    // Create search bar above the top of the window, then animate it into position
    if (self.searchBar == nil) {
        self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,-74,self.view.frame.size.width,44)];
        self.searchBar.delegate = self;
        self.searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
        self.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
        self.searchBar.showsCancelButton = YES;
        [nc.view addSubview:self.searchBar];
    }
    [UIView animateWithDuration:UINavigationControllerHideShowBarDuration animations:^ {
        self.searchBar.frame = nc.navigationBar.frame;} ];
    [self.searchBar becomeFirstResponder];
}

- (void)removeSearchBar
{
    [self.searchBar removeFromSuperview];
    self.searchBar = nil;
}

#pragma mark - Movement Buttons

// This is necessary to allow our 'tap' recognizer to work
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

- (IBAction)onTapInWebView:(UIGestureRecognizer *)recognizer {
    //NSLog(@"Tap");
    CGFloat alpha = buttonsVisible ? 0.05 : 1.0;
    [self animateButtonsToAlpha:alpha duration:0.2];
    buttonsVisible = !buttonsVisible;
}

// Toggle the 'starred' setting on the current message
- (IBAction)onStarButtonPressed:(id)sender {
    if (self.currentMessage != nil && !self.currentMessage.isOutboxMessage && !self.currentMessage.isPlaceholder) {
        [[iXolrAppDelegate singleton] toggleFavouriteMessage:self.currentMessage];
        [self showMessageFlags:self.currentMessage];
    }
}

- (IBAction)onLockButtonPressed:(id)sender {
    if (self.currentMessage != nil && self.currentMessage.isOutboxMessage) {
        CIXMessage *message = (CIXMessage*) self.currentMessage;    // Cast ok - outbox messages are always real messages
        message.isHeld = !message.isHeld;
        [[iXolrAppDelegate singleton].dataController saveContext];  // Commit to database
        [self showMessageFlags:self.currentMessage];
    }
}

- (IBAction)onEditButtonPressed:(id)sender {
    if (self.currentMessage != nil)
        [MessageEditViewController popupMessageEdit:(CIXMessage*)self.currentMessage commentTo:(CIXMessage*)[self currentMessageOriginal] from:self delegate:self];
}

- (IBAction)onFlowButtonPressed:(id)sender {
    [iXolrAppDelegate settings].reflowText = ![iXolrAppDelegate settings].reflowText;
    [self showMessageDetail:self.currentMessage movingBack:YES];
}

- (void)moveToFirstUnreadMessage
{
    NSObject<GenericMessage> *nextMsg = [self.messageTableController firstUnread];
    if (nextMsg != nil) 
        [self moveToDisplayMessage:nextMsg movingBack:NO];
    else    // There is no unread message in this topic - something is wrong with the topic's message counts so get it to do a recount
        [self.topic messageMultipleReadStatusChanged];
}

- (IBAction)gotoNextUnread:(id)sender {
    if (self.currentMessage != nil)
        [self markMessageRead:self.currentMessage status: YES];
    if (self.topic.messagesUnreadCount > 0)
    {
        // Find next unread in this topic
        NSObject<GenericMessage> *nextMsg = [self.messageTableController nextUnread];
        if (nextMsg != nil) {
            [self moveToDisplayMessage:nextMsg movingBack:NO];
            return;
        }
    }
    // Nothing unread in this topic; look for the next topic with interesting unread messages
    Topic *next = [[iXolrAppDelegate singleton].dataController nextTopicWithUnreadAfter: self.topic];
    if (next == self.topic) {
        [self moveToFirstUnreadMessage];
    } else if (next != nil) {
        [[iXolrAppDelegate singleton] gotoTopic:next msgnum:0 switchSubview:YES];
    } else
        [[iXolrAppDelegate singleton].dataController alertNoMoreUnread];
}

- (IBAction)gotoNextPriotrity:(id)sender
{
    if (self.currentMessage != nil)
        [self markMessageRead:self.currentMessage status: YES];
    NSObject<GenericMessage> *nextMsg = [self.messageTableController nextInteresting];
    if (nextMsg != nil)
        [self moveToDisplayMessage:nextMsg movingBack:NO];
    else {
        Topic *next = [[iXolrAppDelegate singleton].dataController nextInterestingTopicAfter: self.topic];
        if (next != nil) {
            [[iXolrAppDelegate singleton] gotoTopic:next msgnum:-1 switchSubview:YES];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"No more priority messages" message:@"There are no more priority messages in your messagebase." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [alert show];
        }
    }
}

- (IBAction)backToLastRead {
    if ([lastVisited count] > 0) {
        CIXMessage *message = [lastVisited lastObject];
        [self moveToDisplayMessage:message movingBack:YES];
        [lastVisited removeLastObject];
    }
}

- (NSObject<GenericMessage>*)currentMessageOriginal
{
    return [self.messageTableController messageWithNumber:self.currentMessage.commentTo];
}

- (IBAction)gotoOriginal {
    NSObject<GenericMessage> *original = [self currentMessageOriginal];
    if (original != nil) 
        [self moveToDisplayMessage:original movingBack:NO];
}

- (void)moveToDisplayMessageNumber:(NSInteger)msgnum
{
    CIXMessage *message = [self.topic messageWithNumber:msgnum];
    if (message == nil) 
        message = [self.messageTableController addPlaceholder:msgnum topic:self.topic];
    [self moveToDisplayMessage:message movingBack:NO];
    [self.messageTableController forceRedrawOfMessage:message];
}

// Move both parts of the view to show a particular message, reading an entire new topic if necessary
- (void)moveToDisplayMessage:(NSObject<GenericMessage>*)message movingBack:(BOOL)back
{
    if (message == nil) {
        return;
    }
    BOOL isTopicNew = NO;
    if (message.topic != self.topic) {
        self.topic = message.topic;
        isTopicNew = YES;
    }
    if (self.currentMessage != message)
        [self showMessageDetail:message movingBack:back];
    [self.messageTableController moveToDisplayMessage:message topicNew:isTopicNew animated:hasAppeared];
}

#pragma mark - ThreadedMessageList delegate

-(void)threadedMessageList:(ThreadedMessageListVC*)threadHeaderView messageSelected:(NSObject<GenericMessage>*)message
{
    [self showMessageDetail:message movingBack:NO];
}

#pragma mark - Search Bar

// Widen the search bar when it starts editing
- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    // currently displaying actionsheet?
    if (_actionSheet || _activityPopover)
        [self popdownActionSheet];

    if ([iXolrAppDelegate iPad]) {
        searchBar.placeholder = @"Search text";
        [searchBar.superview layoutIfNeeded];
        self.searchBarWidth.constant += 100;
        [UIView animateWithDuration:0.25f delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{[searchBar.superview layoutIfNeeded];} completion:^(BOOL finished) {}];
    }
    return YES;
}

// User has finished with search bar
- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar
{
    if ([iXolrAppDelegate iPad]) {
        [searchBar.superview layoutIfNeeded];
        self.searchBarWidth.constant -= 100;
        [UIView animateWithDuration:0.25f delay:0 options:UIViewAnimationOptionLayoutSubviews animations:^{[searchBar.superview layoutIfNeeded];} completion:^(BOOL finished) {}];
        searchBar.placeholder = nil;
    } else
        // Animate back up off the top of the screen
        [UIView animateWithDuration:UINavigationControllerHideShowBarDuration animations:^ {
            self.searchBar.center = CGPointMake(self.searchBar.center.x, self.searchBar.center.y-74);} ];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [self.searchBar resignFirstResponder];  // Causes searchBarTextDidEndEditing callback
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Find next message matching search text in this topic
    NSObject<GenericMessage> *nextMsg = [self.messageTableController nextMessageMatching:searchBar.text];
    if (nextMsg != nil) {
        [self moveToDisplayMessage:nextMsg movingBack:NO];
        return;
    }
}

#pragma mark - CIXMessage bar

- (IBAction)headerBarDragInside:(id)sender withEvent:(UIEvent *) event
{
    CGPoint point = [[[event allTouches] anyObject] locationInView:self.headerView];
    // Compute the new position of the header bar 
    CGFloat y = self.lowerView.frame.origin.y + point.y - self.headerView.center.y;
    if (y < 50 || y > self.view.frame.size.height - 120)  // Don't let it drag too far
        return; 
    [self positionHeaderAtYCoord:y];
    [iXolrAppDelegate singleton].threadWindowSize = y / self.view.frame.size.height;
}

#pragma mark - Hardware Keyboard handling

- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (NSArray *) keyCommands
{
    static NSArray *array = nil;
    // Don't steal any keys when we have popped up another window
    if ([self presentedViewController] != nil)
        return nil;
    if (array == nil) {
        array = @[
            [UIKeyCommand keyCommandWithInput: UIKeyInputUpArrow    modifierFlags: 0 action: @selector(upArrow)],
            [UIKeyCommand keyCommandWithInput: UIKeyInputDownArrow  modifierFlags: 0 action: @selector(downArrow)],
            [UIKeyCommand keyCommandWithInput: UIKeyInputLeftArrow  modifierFlags: 0 action: @selector(leftArrow)],
            [UIKeyCommand keyCommandWithInput: UIKeyInputRightArrow modifierFlags: 0 action: @selector(rightArrow)],
            [UIKeyCommand keyCommandWithInput: @"\r" modifierFlags: 0 action: @selector(enterKey)],
            [UIKeyCommand keyCommandWithInput: @"\b" modifierFlags: 0 action: @selector(backSpace)],
            [UIKeyCommand keyCommandWithInput: @"o" modifierFlags: 0 action: @selector(oKey)],
            [UIKeyCommand keyCommandWithInput: @"5" modifierFlags: 0 action: @selector(fiveKey)],
            [UIKeyCommand keyCommandWithInput: @"p" modifierFlags: 0 action: @selector(pKey)],
            [UIKeyCommand keyCommandWithInput: @"i" modifierFlags: 0 action: @selector(iKey)],
            [UIKeyCommand keyCommandWithInput: @"s" modifierFlags: 0 action: @selector(sKey)],
            [UIKeyCommand keyCommandWithInput: @"c" modifierFlags: 0 action: @selector(cKey)],
            [UIKeyCommand keyCommandWithInput: @"t" modifierFlags: 0 action: @selector(tKey)],
            ];
    }
    return array;
}

- (void)    upArrow { [self moveToDisplayMessage:[self.messageTableController prevRow] movingBack:NO]; }
- (void)  downArrow { [self moveToDisplayMessage:[self.messageTableController nextRow] movingBack:NO]; }
- (void)  leftArrow { [self moveToDisplayMessage:[self.messageTableController prevThreadRoot] movingBack:NO]; }
- (void) rightArrow { [self moveToDisplayMessage:[self.messageTableController nextThreadRoot] movingBack:NO]; }
- (void) enterKey   { [self gotoNextUnread:self]; }
- (void) backSpace  { [self backToLastRead]; }
- (void) fiveKey    { [self gotoNextPriotrity:self]; }
- (void) oKey       { [self gotoOriginal]; }
- (void) tKey       { [[iXolrAppDelegate singleton] doSync:self]; }
- (void) pKey {
    if (self.currentMessage != nil && !self.currentMessage.isPlaceholder)
        [self.messageTableController markSubthreadPriority:(CIXMessage*)self.currentMessage status:!self.currentMessage.isInteresting ];
}
- (void) iKey {
    if (self.currentMessage != nil && !self.currentMessage.isPlaceholder)
        [self.messageTableController markSubthreadIgnored:(CIXMessage*)self.currentMessage status:!self.currentMessage.isIgnored ];
}
- (void) sKey       { [self popupNewMessageEditCommentTo:nil]; }
- (void) cKey {
    if (self.currentMessage != nil && !self.currentMessage.isPlaceholder)
        [self popupNewMessageEditCommentTo:(CIXMessage*) self.currentMessage];
}
@end
