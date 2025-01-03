//
//  RootViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "RootViewController.h"

#import "TopicViewController.h"
#import "OutboxViewController.h"
#import "FavouritesVC.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "Conference.h"
#import "Topic.h"
#import "TableViewUtilities.h"
#import "StringUtils.h"

@implementation RootViewController {
@private
	NSMutableArray	*_filteredConferences;	// The list of conferences filtered as a result of a search.
    TopicViewController *topicViewController;
    UIViewController *otherSubViewController;
    BOOL _reloadConfPending;
    UIBarButtonItem *_savedRightButtonItem;
    UIGestureRecognizer *_longPressGestureRecognier;
    NSInteger _cachedTotalUnread;
    NSInteger _cachedTotalInteresting;
}

@synthesize conferences=_conferences;
@synthesize progressView;
		
enum SectionEnum {
    StarredSection,
    OutboxSection,
    MyMessagesSection,
    ConferencesSection,
    SectionCount
};

// Set the toolbar into its static state, not displaying any activity in progress
- (void)updateToolbar
{
    [self.toolbarItems updateToolbar];
    [self.toolbarItems setImageOnSquishButton: self.navigationItem.rightBarButtonItem];
    self.progressView.hidden = YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.preferredContentSize = CGSizeMake(320.0, 600.0);

    // Create a swipe gesture recognizer to recognize right swipes.
	_longPressGestureRecognier = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeFrom:)];
	[self.tableView addGestureRecognizer:_longPressGestureRecognier];
    
	UIGestureRecognizer *recognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleSwipeTitle:)];
    [self.navigationController.navigationBar addGestureRecognizer:recognizer];
    
    if ([iXolrAppDelegate iPad]) {  // Remove fast-forward button on iPad because it looks and works weird there.
        NSMutableArray *tbi = [self.toolbarItems mutableCopy];
        [tbi removeLastObject];
        self.toolbarItems = tbi;
    }
    
	_filteredConferences = [NSMutableArray arrayWithCapacity:100];
    
    self.searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    self.searchController.searchResultsUpdater = self;
    self.tableView.tableHeaderView = self.searchController.searchBar;
    self.definesPresentationContext = YES;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleNewMessages:) name:@"newMessages" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedConference:) name:@"changedConference" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedMessagesInTopic:) name:@"changedMessagesInTopic" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageReadCountChanged:) name:@"messageReadCountChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTopicChanged:) name:@"currentTopicChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshStarted:) name:@"refreshStarted" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshProgress:) name:@"refreshProgress" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshFinished:) name:@"refreshFinished" object:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"outboxMessages" options:0 context:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"favouriteMessages" options:0 context:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"myMessages" options:0 context:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"countOfUnread" options:0 context:nil];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:@"countOfInteresting" options:0 context:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handlePostingMessage:) name:@"postingMessage" object:nil];
}

- (void)updateCountsOnConference:(Conference*)conf andGlow:(BOOL)glow
{
    NSUInteger row = [self.conferences indexOfObject:conf];
    if (row != NSNotFound)
    {
        if (self.isViewLoaded) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:ConferencesSection];
            UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:path];
            [self configureCell:cell inView:self.tableView atIndexPath:path];
            if (glow && self.tableView.window != nil)
                [cell.detailTextLabel pulseGlow];
        }
    }
    else
        [self addOneConference:conf];
}

- (void)updateTotalUnreadDisplay
{
    NSInteger totalUnread = [iXolrAppDelegate singleton].dataController.countOfUnread;
    NSInteger totalInteresting = [iXolrAppDelegate singleton].dataController.countOfInteresting;
    if (_cachedTotalUnread != totalUnread) {
        self.title = [NSString stringWithFormat:@"CIX (%ld)", (long)totalUnread];
        // Create a back button every time because iOS 11 stopped updating it when this title changes.
        // See https://stackoverflow.com/q/46691009/448734
        UIBarButtonItem *btnBack = [[UIBarButtonItem alloc] initWithTitle:self.title style:UIBarButtonItemStylePlain
                                                                   target:nil action:nil];
        self.navigationItem.backBarButtonItem = btnBack;
    }
    if (_cachedTotalInteresting != totalInteresting && [iXolrAppDelegate singleton].badgeAllowed)
        if (@available(iOS 16.0, *)) {
            [[UNUserNotificationCenter currentNotificationCenter] setBadgeCount:totalInteresting withCompletionHandler:nil];
        } else {
            [[UIApplication sharedApplication] setApplicationIconBadgeNumber:totalInteresting];
        }
    _cachedTotalUnread = totalUnread;
    _cachedTotalInteresting = totalInteresting;
}

// Notification has arrived of new messages in one topic
- (void)handleChangedMessagesInTopic:(NSNotification*)param
{
    Topic *topic = [param object];
    [self updateCountsOnConference:topic.conference andGlow:YES];
}

// Notification has arrived of new messages in the database; update the status text
- (void)handleNewMessages:(NSNotification*)param
{
    int numMessages = [[param object] intValue];
    if (numMessages > 0) {
        [self.toolbarItems statusLabel].text = [NSString stringWithFormat:@"%d message%s downloaded", numMessages, numMessages==1 ? "" : "s" ];
    } 
    else
        [self performSelector:@selector(updateToolbar) withObject:nil afterDelay:0.5 ];
}

// Notification has arrived that something changed about a conference: either new topics were added, or it was resigned
- (void)handleChangedConference:(NSNotification*)param
{
    [self updateCountsOnConference:[param object] andGlow:NO];
}

// Notification has arrived that the read-count of a topic has changed.
- (void)handleMessageReadCountChanged:(NSNotification*)param
{
    Topic *topic = [param object];
    [self updateCountsOnConference:topic.conference andGlow:NO];
}

// If showing something like the Outbox, get rid of it and show a TopicViewController with the specified Topic
- (void)switchSubViewToTopic: (Topic*)topic
{
    if (otherSubViewController != nil) {
        NSMutableArray *viewControllers = [[self navigationController].viewControllers mutableCopy];
        NSUInteger index = [viewControllers indexOfObject:otherSubViewController];
        [self createTopicViewController:topic.conference];
        viewControllers[index] = topicViewController;
        otherSubViewController = nil;
        [self.navigationController setViewControllers:viewControllers animated:NO];
    }
    // Push a topic view controller if we're the root
    else if (topicViewController == nil) {
        [self createTopicViewController:topic.conference];
        [[self navigationController] pushViewController:topicViewController animated:NO];
    }
}

- (void)switchSubViewToOutbox
{
    if ([otherSubViewController isKindOfClass:[OutboxViewController class]])
        return;
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    otherSubViewController = [storyboard instantiateViewControllerWithIdentifier:@"Outbox"];
    otherSubViewController.toolbarItems = self.toolbarItems;   // Keep the toolbar visible
    topicViewController = nil;
    [self.navigationController setViewControllers:@[self, otherSubViewController] animated:YES];
}

- (void)gotoConference:(Conference*)conf
{
    if (self.conferences == nil)
        return;
    NSUInteger row = [self.conferences indexOfObject:conf];
    NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:ConferencesSection];
    [self.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
    [self.tableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionNone animated:[iXolrAppDelegate settings].animationsOn];
}

- (void)currentTopicChanged:(NSNotification*)param
{
    Topic *newTopic = [param object];
    [self gotoConference:newTopic.conference];
}

- (void)handlePostingMessage:(NSNotification*)param
{
    NSUInteger outboxCount = [[iXolrAppDelegate singleton].dataController outboxMessageCountToUpload];
    [self.toolbarItems statusLabel].text = [NSString stringWithFormat:@"  Uploading %lu message%s", (unsigned long)outboxCount, (outboxCount>1) ? "s":""];
    [self.toolbarItems startSpinner];
}

- (void)refreshStarted:(NSNotification*)param
{
    [self.toolbarItems statusLabel].text = [NSString stringWithFormat:@"  %@…", [param object]];
    [self.toolbarItems startSpinner];
}

- (void)refreshProgress:(NSNotification*)param
{
    NSNumber *value = [param object];
    float progress = (value != nil) ? value.floatValue : 0.0f;
    [self.progressView setProgress:progress];
    self.progressView.hidden = NO;
}

- (void)refreshFinished:(NSNotification*)param
{
    [self.toolbarItems stopSpinner];
    if ([param object] != nil)
        [self.toolbarItems statusLabel].text = @"Refresh failed";
    // handleNewMessages will have changed the message so, after a short delay, update the toolbar to its usual look
    [self performSelector:@selector(updateToolbar) withObject:nil afterDelay:3 ];
}

// One of the sets we are observing has changed
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"countOfUnread"] || [keyPath isEqualToString:@"countOfInteresting"]) {
        [self updateTotalUnreadDisplay];
        return;
    }
    BOOL firstTimeSetting = [change[NSKeyValueChangeKindKey] intValue] == NSKeyValueChangeSetting;
    NSUInteger count = 0;
    enum SectionEnum section = 0;
    if ([keyPath isEqualToString:@"outboxMessages"]) {
        count = [[iXolrAppDelegate singleton].dataController outboxMessageCount];
        section = OutboxSection;
    } else if ([keyPath isEqualToString:@"favouriteMessages"]) {
        count = [[iXolrAppDelegate singleton].dataController favouriteMessageCount];
        section = StarredSection;
    } else if ([keyPath isEqualToString:@"myMessages"]) {
        count = [[iXolrAppDelegate singleton].dataController myMessageCount];
        section = MyMessagesSection;
    }
    // If first-time setup or going from 0 to 1 message or down to 0 messages, reload the entire section so it will appear or disappear
    if (firstTimeSetting || count < 2)
        [self.tableView reloadSection:section];
    else {
        NSIndexPath *path = [NSIndexPath indexPathForRow:0 inSection:section];
        [self configureCell:[self.tableView cellForRowAtIndexPath:path] inView:self.tableView atIndexPath:path];
    }
}

- (void)reloadConferences
{
    NSArray *newConferences = [[iXolrAppDelegate singleton].dataController fetchAllConferences];
    if ([iXolrAppDelegate settings].squishRows && !self.editing)
        newConferences = [newConferences filterOutZeroUnread];
    self.conferences = newConferences;
}

// Add one conference which has not been found in the current list; generally because it was squished out
- (void)addOneConference: (Conference*) conf
{
    // Need to do a fetch all to find the right spot to put it
    NSArray *allConferences = [[iXolrAppDelegate singleton].dataController fetchAllConferences];
    NSMutableArray *newConferences = nil;
    NSUInteger posInFullList = [allConferences indexOfObject:conf];
    if (posInFullList == NSNotFound)
        return; // something badly wrong - give up
    // Now loop forward through current list to find the first conf that is after the one we are looking for
    NSUInteger posInCurrentList;
    for (posInCurrentList = 0; posInCurrentList < self.conferences.count; ++posInCurrentList)
        if ([allConferences indexOfObject: self.conferences[posInCurrentList]] > posInFullList)
            break;
    newConferences = [self.conferences mutableCopy];
    [newConferences insertObject:conf atIndex:posInCurrentList];
    self.conferences = newConferences;
}

- (void)asyncLoadConferences
{
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        self->_reloadConfPending = NO;
        [[iXolrAppDelegate singleton].dataController fetchAllTopicCounts];
        [self reloadConferences];
    }];
}

- (NSArray*)conferences
{
    if (_conferences == nil && !_reloadConfPending) {
        _reloadConfPending = YES;
        [self asyncLoadConferences];
    }
    return _conferences;
}

- (void)setConferences:(NSArray *)newConferences
{
    if (_conferences == nil) {
        _conferences = newConferences;
        [self.tableView reloadSection:ConferencesSection];
    } else {
        NSMutableArray *rowsAdded=nil, *rowsDeleted=nil;
        [_conferences computeDifferenceTo:newConferences returningAdded:&rowsAdded andDeleted:&rowsDeleted inSection:ConferencesSection];
        _conferences = newConferences;
        [self.tableView updateWithAdded:rowsAdded andDeleted:rowsDeleted inSection:ConferencesSection];
    }
}
		
- (IBAction)refreshButtonPressed:(id)sender {
    [[iXolrAppDelegate singleton] doSync:self];
}

- (IBAction)squishButtonPressed:(id)sender
{
    if (topicViewController == nil && [iXolrAppDelegate settings].squishRows) {
        // If we're supposed to be squished but there are any conferences in the list with zero unread, just reload to get rid of them
        for (Conference * conf in self.conferences)
            if (conf.messagesUnreadCount == 0) {
                [self reloadConferences];
                return;
            }
    }
    [iXolrAppDelegate settings].squishRows = ![iXolrAppDelegate settings].squishRows;
    [self reloadConferences];
    [self updateToolbar];
    [topicViewController squishButtonPressed:sender];
}

- (IBAction)settingsButtonPressed:(id)sender
{
    TopSettingsVC *settingsVC = [[TopSettingsVC alloc] initWithNibName:@"TopSettings" bundle:nil];
    settingsVC.delegate = self;
    // Create the navigation controller and present it modally.
    UINavigationController *navigationController = [[UINavigationController alloc]
                                                    initWithRootViewController:settingsVC];
    if ([iXolrAppDelegate iPad])
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

- (UIViewController*)createTopicViewController:(Conference*)conf
{
      // Just in case we had one previously
    UIStoryboard * storyboard = [UIStoryboard storyboardWithName:@"Main" bundle:nil];
    topicViewController = [storyboard instantiateViewControllerWithIdentifier:@"Topics"];
    [self setupTopicViewController:conf];
    [topicViewController view];  // force viewDidLoad to fire so subscriptions work
    return topicViewController;
}

- (void)setupTopicViewController:(Conference*)conf
{
    topicViewController.conference = conf;
    [topicViewController configureTitle];   // Need this otherwise title doesn't appear in back button
    topicViewController.toolbarItems = self.toolbarItems;   // Keep the toolbar visible
    topicViewController.navigationItem.rightBarButtonItem = self.navigationItem.rightBarButtonItem;
}

- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum
{
    [self switchSubViewToTopic:topic];
    [topicViewController pushDetailViewControllerTopic:topic msgnum:msgnum];
}

// Toolbar button for 'next unread' pressed (only used on iPhone)
- (IBAction)nextUnreadButtonPressed:(id)sender
{
    // Look for the next topic with interesting unread messages
    Topic *topic = [[iXolrAppDelegate singleton].dataController nextInterestingTopicAfter: nil];
    if (topic != nil) {
        [self gotoTopic:topic msgnum:-1];
    } else {
        // Nothing interesting; look for the next topic with unread messages
        topic = [[iXolrAppDelegate singleton].dataController nextTopicWithUnreadAfter: nil];
        if (topic != nil) {
            [self gotoTopic:topic msgnum:0];
        } else
            [[iXolrAppDelegate singleton] alertNoMoreUnread];
    }
}

#pragma mark - View behaviour

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _cachedTotalUnread = _cachedTotalInteresting = 0;
    // Set property so top-level can control us.  Should really be a push/pop operation.
    [iXolrAppDelegate singleton].conferenceListViewController = self;
    self.searchController.searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    if (self.tableView.contentOffset.y == 0)
        // Move the search bar up out of sight off the top of the window
        [self.tableView setContentOffset: CGPointMake(0, self.searchController.searchBar.frame.size.height) animated:NO];
    [self updateToolbar];
}

- (void)viewDidAppear:(BOOL)animated
{
    topicViewController = nil;
    otherSubViewController = nil;
    if (self.tableView.contentOffset.y == 0)
        // Move the search bar up out of sight off the top of the window
        [self.tableView setContentOffset: CGPointMake(0, self.searchController.searchBar.frame.size.height) animated:NO];
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

// This view is going into or out of editing mode: change the display to reflect this.
- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
    if (editing) {
        _savedRightButtonItem = self.navigationItem.rightBarButtonItem;
        self.navigationItem.rightBarButtonItem = self.editButtonItem;
    } else {
        self.navigationItem.rightBarButtonItem = _savedRightButtonItem;
        _savedRightButtonItem = nil;
    }
    _longPressGestureRecognier.enabled = !editing;
    [super setEditing:editing animated:animated];
    [self reloadConferences];
}

#pragma mark - Swipe callbacks

// Swipe-right to mark all read in conference
- (void)handleSwipeFrom:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) 
        return;
	CGPoint location = [recognizer locationInView:self.view];
    NSIndexPath *indexPath = [self.tableView indexPathForRowAtPoint:location];
    if (indexPath != nil && indexPath.section == ConferencesSection && indexPath.row < self.conferences.count)
    {
        [self.tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        Conference *actionConference = (self.conferences)[indexPath.row];
        NSString *message = [NSString stringWithFormat:@"Available actions for conference %@:", actionConference.name];

        UIAlertController * alert = [UIAlertController popupWithTitle:@"Conference Actions" message:message sourceView:self.tableView sourceRect:CGRectMake(location.x, location.y, 1, 1)];

        [alert addActionWithTitle:@"Mark All Read" ifConfirmed:[NSString stringWithFormat:@"Do you want to mark all messages in conference '%@' as read?", actionConference.name] from:self block:^() {
            [actionConference markAllMessagesRead];
        }];

        if ([actionConference isResigned]) {
            [alert addActionWithTitle:@"Re-join" ifConfirmed:[NSString stringWithFormat:@"Please confirm you want to re-join conference %@?", actionConference.name] from:self block:^() {
                [[iXolrAppDelegate singleton] joinConference:actionConference.name];
            }];
            [alert addActionWithTitle:@"Delete" ifConfirmed:[NSString stringWithFormat:@"Please confirm you want to delete conference %@?", actionConference.name] from:self block:^() {
                [[iXolrAppDelegate singleton].dataController deleteConference:actionConference];
            }];
        } else {
            [alert addActionWithTitle:@"Resign" ifConfirmed:[NSString stringWithFormat:@"Please confirm you want to resign conference %@?", actionConference.name] from:self block:^() {
                [[iXolrAppDelegate singleton] resignConference:actionConference.name];
            }];
            [alert action:@"Re-order" block:^{
                [self setEditing:YES animated:YES];
            }];
        }

        [alert addCancelAction:^{}];

        [self presentViewController:alert animated:YES completion:nil];
    }
}

// Swipe-right on title - pass to topmost view controller
- (void)handleSwipeTitle:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) 
        return;
    if ([self.navigationController.topViewController respondsToSelector:@selector(titleSwipeCommands)])
        [self.navigationController.topViewController performSelector:@selector(titleSwipeCommands)];
}

// Swipe-right on title to perform an action across all conferences
- (void)titleSwipeCommands
{
    UIAlertController * alert = [UIAlertController popupWithTitle:@"Top-Level Actions" message:@"These actions apply across all conferences" sourceView:self.navigationController.navigationBar sourceRect:self.navigationController.navigationBar.frame];

    [alert addActionWithTitle:@"Mark All Read" ifConfirmed:@"Do you want to mark all messages in all conferences as read?" from:self block:^() {
        [[iXolrAppDelegate singleton].dataController markReadOlderThanDate: [NSDate distantFuture]];
    }];
    [alert addActionWithTitle:@"Sync Unread with CIX" ifConfirmed:@"Do you want to sync the unread status of all messages with CIX?" from:self block:^() {
        [[iXolrAppDelegate singleton] cosySync: YES];
    }];
    [alert action:@"Purge old messages" block:^{
        [[iXolrAppDelegate singleton] purgeIfConfirmedFrom:self Rect:[self.view convertRect: self.navigationController.navigationBar.frame fromView:self.navigationController.navigationBar]];
    }];
    [alert addCancelAction:^{}];

    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Segues

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"topics"]) {
        topicViewController = [segue destinationViewController];
        UITableViewCell *cell = sender;
        [self setupTopicViewController:[[iXolrAppDelegate singleton].dataController conferenceWithName:cell.textLabel.text]];
    } else {
        otherSubViewController = [segue destinationViewController];
        otherSubViewController.toolbarItems = self.toolbarItems;   // Keep the toolbar visible
    }
}

#pragma mark - Table callbacks

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	if (self.searchController.active)
        return 1;
    return SectionCount; 
}

		
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.searchController.active)
        return [_filteredConferences count];
    if (section == ConferencesSection)
        return [self.conferences count];
    else if (section == OutboxSection) {
        if ([[iXolrAppDelegate singleton].dataController outboxMessageCount] > 0)
            return 1;
    }
    else if (section == MyMessagesSection) {
        if ([iXolrAppDelegate settings].myMessagesVisible && [[iXolrAppDelegate singleton].dataController myMessageCount] > 0)
            return 1;
    }
    else if (section == StarredSection) {
        if ([[iXolrAppDelegate singleton].dataController favouriteMessageCount] > 0)
            return 1;
    }
    return 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (self.searchController.active)
        return nil;
    if (section == ConferencesSection) {
        if (_reloadConfPending)
            return @"Loading...";
        else if ([self.conferences count] == 0)
            if ([iXolrAppDelegate settings].squishRows)
                return @"No unread messages";
            else
                return @"Hit ⚙ to get started";
        else
            return nil;
    }
    else
        return nil;
}
		
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifiers[] = {@"StarredCell", @"OutboxCell", @"MyMessagesCell", @"ConfCell"};
    UITableViewCell *cell;
    if (self.searchController.active)
        cell = [self.tableView dequeueReusableCellWithIdentifier:CellIdentifiers[ConferencesSection]];
    else
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifiers[indexPath.section] forIndexPath:indexPath];

    [self configureCell:cell inView:tableView atIndexPath:indexPath];
        
    return cell;
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == ConferencesSection;
}

- (NSIndexPath *)tableView:(UITableView *)tableView targetIndexPathForMoveFromRowAtIndexPath:(NSIndexPath *)sourceIndexPath toProposedIndexPath:(NSIndexPath *)proposedDestinationIndexPath
{
    if (proposedDestinationIndexPath.section == ConferencesSection)
        return proposedDestinationIndexPath;
    else
        return [NSIndexPath indexPathForRow:0 inSection:ConferencesSection];
}

- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)sourceIndexPath toIndexPath:(NSIndexPath *)destinationIndexPath
{
    //NSLog(@"Conference moveRowAtIndexPath: [%d,%d] to: [%d,%d]", sourceIndexPath.section, sourceIndexPath.row, destinationIndexPath.section, destinationIndexPath.row);
    if (![sourceIndexPath isEqual:destinationIndexPath]) {
        if (destinationIndexPath.section == ConferencesSection && self.conferences != nil) {
            NSMutableArray *newConferences = [self.conferences mutableCopy];
            [newConferences removeObjectAtIndex:sourceIndexPath.row];
            [newConferences insertObject:(self.conferences)[sourceIndexPath.row] atIndex:destinationIndexPath.row];
            NSInteger confCount = newConferences.count;
            for (int row = 0; row < confCount; ++row) {
                Conference *conf = newConferences[row];
                if (row > destinationIndexPath.row && conf.ordering >= (-confCount + row))    // rows further down than the destination that already sort correctly we can leave alone
                    break;
                if (conf.ordering != (-confCount + row))
                    conf.ordering = (int32_t)(-confCount + row);
            }
            [[iXolrAppDelegate singleton].dataController saveContext];
                 // Bypass setConferences method
            _conferences = newConferences;
        }
        else {
            // This shouldn't happen - we forbad it in targetIndexPathForMoveFromRowAtIndexPath:
        }
    }
}

- (Conference*)conferenceAtIndexPath: (NSIndexPath *)indexPath inView:(UITableView *)tableView
{
    if (self.searchController.active)
        return _filteredConferences[indexPath.row];
    else
        return (self.conferences)[indexPath.row];
}

- (void)configureCell:(UITableViewCell *)cell inView:(UITableView *)tableView atIndexPath:(NSIndexPath *)indexPath
{
    UIColor *textColor = basicTextColor();
    if (indexPath.section == ConferencesSection || self.searchController.active) {   // Ordinary conference cell or search in progress
        Conference *conf = [self conferenceAtIndexPath:indexPath inView:tableView];
        cell.textLabel.text = conf.name;
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)conf.messagesUnreadCount, (long)conf.messageCount];
        cell.accessoryType = UITableViewCellAccessoryNone;

        // Colour grey if resigned
        if (conf.isResigned)
            textColor = grayTextColor();
        cell.imageView.image = nil;
    }
    else if (indexPath.section == OutboxSection) {
        NSUInteger outboxSize = [[iXolrAppDelegate singleton].dataController outboxMessageCount];
        cell.detailTextLabel.text = [NSString fromNSUInteger: outboxSize];
    }
    else if (indexPath.section == MyMessagesSection) {
        NSUInteger myMessageSize = [[iXolrAppDelegate singleton].dataController myMessageCount];
        cell.detailTextLabel.text = [NSString fromNSUInteger: myMessageSize];
    }
    else if (indexPath.section == StarredSection) {
        NSUInteger size = [[iXolrAppDelegate singleton].dataController favouriteMessageCount];
        cell.detailTextLabel.text = [NSString fromNSUInteger: size];
    }
    cell.textLabel.textColor = textColor;
}

// Restoration of rows doesn't work when the data is populated asynchronously much later.
- (NSString *)modelIdentifierForElementAtIndexPath:(NSIndexPath *)indexPath inView:(UIView *)view
{
    if (indexPath != nil)
        switch (indexPath.section)
        {
            case ConferencesSection:
            {
                Conference *conf = self.conferences[indexPath.row];
                return conf.name;
            }
            case OutboxSection:
                return @"iXolr.Outbox";
            case MyMessagesSection:
                return @"iXolr.My Messages";
            case StarredSection:
                return @"iXolr.Starred";
        }
    return nil;
}

- (NSIndexPath *)indexPathForElementWithModelIdentifier:(NSString *)identifier inView:(UIView *)view
{
    if ([identifier isEqualToString:@"iXolr.Outbox"])
        return [NSIndexPath indexPathForRow:0 inSection:OutboxSection];
    else if ([identifier isEqualToString:@"iXolr.My Messages"])
        return [NSIndexPath indexPathForRow:0 inSection:MyMessagesSection];
    else if ([identifier isEqualToString:@"iXolr.Starred"])
        return [NSIndexPath indexPathForRow:0 inSection:StarredSection];
    else {
        if (_conferences == nil)
            return nil;
        else
            return [NSIndexPath indexPathForRow:[self.conferences indexOfObject:identifier] inSection:ConferencesSection];
    }
}

#pragma mark - Content Filtering

- (void)filterContentForSearchText:(NSString*)searchText scope:(NSString*)scope
{
	[_filteredConferences removeAllObjects]; 
	
	for (Conference *conf in self.conferences)
	{
        if ([searchText isEqualToString:@""] || [conf.name rangeOfString:searchText].location != NSNotFound)
            [_filteredConferences addObject:conf];
	}
}


#pragma mark - Protocol UISearchResultsUpdating Methods

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController
{
    [self filterContentForSearchText:searchController.searchBar.text scope: @"unused"];
    [self.tableView reloadData];
}


#pragma mark - Lifecycle

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];

    // Relinquish ownership any cached data, images, etc that aren't in use.
}


@end
