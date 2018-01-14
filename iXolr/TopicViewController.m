//
//  TopicViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 31/05/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "TopicViewController.h"
#import "Conference.h"
#import "Topic.h"
#import "TableViewUtilities.h"
#import "iXolrAppDelegate.h"
#import "DetailViewController.h"

@interface TopicViewController ()
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;
- (void)handleNewMessagesOrTopics:(NSNotification*)param;
@end

@implementation TopicViewController

@synthesize topicsArray;
@synthesize conference;
@synthesize currentTopic;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Need this one initialized even before we get loaded, because it can change the title
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTopicChanged:) name:@"currentTopicChanged" object:nil];
    }
    return self;
}

- (NSArray *)getTopicArray
{
    NSArray *newTopics = [self.conference topicsSortedArray];
    if ([iXolrAppDelegate settings].squishRows)
        newTopics = [newTopics filterOutZeroUnreadExcept:self.currentTopic];
    return newTopics;
}

- (void) configureTitle
{
    NSString *title = self.conference.name;
    if (![iXolrAppDelegate iPad]) {
        while ([title sizeWithFont:[UIFont systemFontOfSize:34]].width > 215) // Shorten if too long
            title = [[self.conference.name substringToIndex:title.length - 2] stringByAppendingString: @"…"];
    }
    [self.navigationItem setTitle: title];
}

- (void) configureForConference
{
    self.topicsArray = [self getTopicArray];
    [self.tableView reloadData];
    [self configureTitle];
    if (self.currentTopic != nil && self.currentTopic.conference == self.conference) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:[self.topicsArray indexOfObject:self.currentTopic] inSection:0];
        [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

// This class displays all the topics for a conference.
// We expect that someone has populated the property 'self.conference' before displaying us.
- (void)viewDidLoad
{
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.preferredContentSize = CGSizeMake(320.0, 600.0);

    // Create a swipe gesture recognizer to recognize right swipes.
	UIGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeFrom:)];
	[self.view addGestureRecognizer:recognizer];

    if ([self.conference.name isEqualToString:[iXolrAppDelegate singleton].currentConferenceName])
        self.currentTopic = [self.conference topicWithName:[iXolrAppDelegate singleton].currentTopicName];
    [self configureForConference];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNewMessagesOrTopics:) name:@"newMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNewMessagesOrTopics:) name:@"changedConference" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedMessagesInTopic:) name:@"changedMessagesInTopic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageReadCountChanged:) name:@"messageReadCountChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTopicChanged:) name:@"currentTopicChanged" object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [self.toolbarItems updateToolbar];
    [[self navigationController] setToolbarHidden:NO animated:animated];
    [super viewWillAppear: animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    [super didRotateFromInterfaceOrientation:fromInterfaceOrientation];
    // Get the toolbar colouration correct
    [self.toolbarItems updateToolbar];
}

- (BOOL)updateCountsOnTopic:(Topic*)topic andGlow:(BOOL)glow
{
    NSUInteger row = [topicsArray indexOfObject:topic];
    if (row != NSNotFound)
    {
        NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
        [self configureCell:cell atIndexPath:path];
        if (glow)
            [cell.detailTextLabel pulseGlow];
        return YES;
    }
    else
        return NO;
}

// Notification has arrived of new messages in one topic
- (void)handleChangedMessagesInTopic:(NSNotification*)param
{
    Topic *topic = [param object];
    if (topic.conference == self.conference)
        if (![self updateCountsOnTopic:topic andGlow:YES])
            return;   // @TODO: If I knew which order the topic list is in, I could add this new topic at the right place
}

// Notification has arrived of new messages in the database
- (void)handleNewMessagesOrTopics:(NSNotification*)param
{
    if (self.conference != nil) {
        NSMutableArray *rowsAdded=nil, *rowsDeleted=nil;
        NSArray *newTopics = [self getTopicArray];
        [topicsArray computeDifferenceTo:newTopics returningAdded:&rowsAdded andDeleted:&rowsDeleted inSection:0];
        self.topicsArray = newTopics;
        [self.tableView updateWithAdded:rowsAdded andDeleted:rowsDeleted inSection:0];
    }
}

- (void)squishButtonPressed:(id)sender
{
    [self handleNewMessagesOrTopics:nil];   // reload topics and update the display
}

- (void)handleMessageReadCountChanged:(NSNotification*)param
{
    Topic *topic = [param object];
    [self updateCountsOnTopic:topic andGlow:NO];
}

- (void)currentTopicChanged:(NSNotification*)param
{
    Topic *newTopic = [param object];
    self.currentTopic = newTopic;
    if (newTopic == nil) {
        [self.tableView deselectRowAtIndexPath:[self.tableView indexPathForSelectedRow] animated:NO];
        return;
    }
    if (newTopic.conference != self.conference)
    {
        self.conference = newTopic.conference;
        [self configureForConference];
    }
    NSUInteger row = [topicsArray indexOfObject:newTopic];
    if (row == NSNotFound) {    // Topic has been squished out - put it back so we can see where we are
        [self handleNewMessagesOrTopics:nil];
        row = [topicsArray indexOfObject:self.currentTopic];
    }
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
    [self.tableView selectRowAtIndexPath:path animated:YES scrollPosition:UITableViewScrollPositionMiddle];
}

- (void)pushDetailViewControllerTopic:(Topic*)topic msgnum:(NSInteger)msgnum
{
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    UINavigationController* nc = [storyboard instantiateViewControllerWithIdentifier:@"Detail"];
    DetailViewController *vc = (DetailViewController*)[nc topViewController];
    [[self navigationController] pushViewController:nc animated:YES];
    [vc gotoTopic:topic msgnum:msgnum];
}

#pragma mark - Swipe callbacks

// Swipe-right on title to perform an action across all topics in this conference
- (void)titleSwipeCommands 
{
    NSString *message = [NSString stringWithFormat:@"Available actions for conference %@:", conference.name];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Actions" message:message completionBlock:^(NSUInteger buttonIndex) {
        if (buttonIndex > 0) {
            NSString *message2 = nil;
            switch (buttonIndex) {
                case 1:
                    message2 = [NSString stringWithFormat:@"Do you want to mark all messages in conference '%@' as read?", conference.name];
                    break;
                case 2:
                    message2 = @"Do you want to fly to the moon?";
                    break;
            }
            UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:@"Confirm" message:message2 completionBlock:^(NSUInteger button2Index) {
                if (button2Index == 1)
                    switch (buttonIndex) {
                        case 1:
                            [conference markAllMessagesRead];
                            break;
                        case 2:
                            break;
                    }
            }
                                                   cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
            [alert2 show];
        }
    }
                                          cancelButtonTitle:@"Cancel" otherButtonTitles:@"Mark All Read", nil];
    
    [alert show];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        Topic *topic = topicsArray[indexPath.row];
        DetailViewController *vc = [DetailViewController findDetailViewFrom: segue];
        [vc gotoTopic:topic msgnum:0];
    }
}

#pragma mark - Table View callbacks

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [topicsArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if ([topicsArray count] == 0)
        return @"No topics with unread messages";
    else
        return @"Topics";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TopicCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    // Configure the cell.
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Topic *topic = topicsArray[indexPath.row];
    if (topic.isReadOnly)
        cell.textLabel.text = [topic.name stringByAppendingString:@" [readonly]"];
    else
        cell.textLabel.text = topic.name;
    cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)topic.messagesUnreadCount, (long)topic.messageCount];
    UIColor *textColor = [UIColor blackColor];
    if (topic.isMute || topic.isResigned)
        textColor = [textColor colorWithAlphaComponent:0.5];
    cell.textLabel.textColor = textColor;
}

// A specific topic has been selected: pass this on to the message viewer
- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if(self.splitViewController == nil || ([iXolrAppDelegate iOS8] && self.splitViewController.collapsed))
        [self performSegueWithIdentifier: @"showDetail" sender: self];
    else
        [[iXolrAppDelegate singleton] gotoTopic:topicsArray[indexPath.row] msgnum:0];
}

// Swipe-right to mark all read
- (void)handleSwipeFrom:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) 
        return;
	CGPoint location = [recognizer locationInView:self.view];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    if (indexPath != nil && indexPath.row < topicsArray.count)
    {
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        Topic *topic = topicsArray[indexPath.row];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Topic Actions" message:nil completionBlock:^(NSUInteger buttonIndex) {
            if (buttonIndex > 0) {
                NSString *message2 = nil;
                UIAlertView *alert2 = nil;
                switch (buttonIndex) {
                    case 1:
                    {
                        message2 = [NSString stringWithFormat:@"Please confirm you want to mark all messages in topic %@ as read?", topic.name];
                        alert2 = [[UIAlertView alloc] initWithTitle:@"Confirm" message:message2 completionBlock:^(NSUInteger button2Index) {
                            if (button2Index == 1)
                                [topic markAllMessagesRead];
                        }
                           cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
                        break;
                    }
                    case 2:
                    {
                        NSString *title2 = [NSString stringWithFormat:@"Backfill %@/%@?", topic.conference.name, topic.name];
                        alert2 = [[UIAlertView alloc] initWithTitle:title2 message:@"Download older messages from CIX" completionBlock:^(NSUInteger button2Index) {
                            switch (button2Index) {
                                case 1:
                                    [topic downloadMissingMessages:10];
                                    break;
                                case 2:
                                    [topic downloadMissingMessages:100];
                                    break;
                                case 3:
                                    [topic downloadMissingMessages:500];
                                    break;
                                case 4:
                                    [topic downloadMissingMessages:99999];
                                    break;
                            }
                        }
                            cancelButtonTitle:@"Cancel" otherButtonTitles:@"10 messages", @"100 messages", @"500 messages", @"All messages", nil];
                        break;
                    }
                    case 3:
                    {
                        message2 = [NSString stringWithFormat:@"Please confirm you want to mark topic %@ as %@?", topic.name, topic.isMute ? @"non-mute" : @"mute"];
                        alert2 = [[UIAlertView alloc] initWithTitle:@"Confirm" message:message2 completionBlock:^(NSUInteger button2Index) {
                            if (button2Index == 1)
                                topic.isMute = !topic.isMute;
                        }
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
                        break;
                    }
                    case 4:
                    {
                        message2 = [NSString stringWithFormat:@"Please confirm you want to resign topic %@", topic.name];
                        alert2 = [[UIAlertView alloc] initWithTitle:@"Confirm" message:message2 completionBlock:^(NSUInteger button2Index) {
                            if (button2Index == 1)
                                [[iXolrAppDelegate singleton] resignConference:topic.conference.name topic:topic.name];
                        }
                                                  cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
                        break;
                    }
                }
                [alert2 show];
            }
        }
                                              cancelButtonTitle:@"Cancel" otherButtonTitles:@"Mark All Read", @"Backfill older messages",topic.isMute ? @"Un-mute topic" : @"Mute topic", @"Resign topic", nil];
        
        [alert show];
    }
}

#pragma mark - Lifecycle

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc that aren't in use.
}


@end
