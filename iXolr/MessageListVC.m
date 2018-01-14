//
//  MessageListVC.m
//  iXolr
//
//  Created by Bryan Boreham on 01/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "MessageListVC.h"
#import "Message.h"
#import "TableViewUtilities.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "DetailViewController.h"

@implementation MessageListVC {
@private
    BOOL _observingMessages;
}

@synthesize messages;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [[iXolrAppDelegate singleton].dataController removeObserver:self forKeyPath:[self keyPathForMessages]];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (NSString*)keyPathForMessages
{
    return nil; // Must be implemented by subclasses
}

- (void) observeMessages
{
    if (!_observingMessages)
        for (NSObject *message in self.messages) {
            [message addObserver:self forKeyPath:@"text" options:0 context:nil];
            [message addObserver:self forKeyPath:@"flags" options:0 context:nil];
        }
    _observingMessages = YES;
}

- (void) unobserveMessages
{
    if (_observingMessages)
        for (NSObject *message in self.messages) {
            [message removeObserver:self forKeyPath:@"text"];
            [message removeObserver:self forKeyPath:@"flags"];
        }
    _observingMessages = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = NO;
    self.preferredContentSize = CGSizeMake(320.0, 600.0);
    
    self.messages = [[iXolrAppDelegate singleton].dataController valueForKeyPath:[self keyPathForMessages]];
    [[iXolrAppDelegate singleton].dataController addObserver:self forKeyPath:[self keyPathForMessages] options:0 context:nil];
}

// When we come back from showing a message, make the toolbar re-appear
- (void)viewWillAppear:(BOOL)animated
{
    [[self navigationController] setToolbarHidden:NO animated:animated];
    [self.tableView reloadData];
    [self observeMessages];
    [super viewWillAppear: animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self unobserveMessages];
    [super viewWillDisappear: animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

// Callback from key-value observing - something has changed...
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if ([keyPath isEqualToString:[self keyPathForMessages]]) {  // is it the whole set that has changed?
    [self unobserveMessages];
    NSMutableArray *rowsAdded=nil, *rowsDeleted=nil;
    NSArray *newMessages = [object valueForKeyPath:keyPath];
    [self.messages computeDifferenceTo:newMessages returningAdded:&rowsAdded andDeleted:&rowsDeleted inSection:0];
    self.messages = newMessages;
    [self.tableView updateWithAdded:rowsAdded andDeleted:rowsDeleted inSection:0];
    [self observeMessages];
    } else {
    NSInteger row = [messages indexOfObject:object];    // or one of the messages in it?
    if (row != NSNotFound) {
        NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
        [self configureCell:[self.tableView cellForRowAtIndexPath:path] atIndexPath:path];
    }
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [messages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"MessageCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
		cell = [self tableViewCellWithReuseIdentifier:CellIdentifier];
    }

    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (UITableViewCell *)tableViewCellWithReuseIdentifier:(NSString *)identifier {
    return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    CIXMessage *message = messages[indexPath.row];
    cell.textLabel.text = message.summary;
    cell.detailTextLabel.text = message.firstLine;
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return YES;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CIXMessage *message = messages[indexPath.row];
    if (![iXolrAppDelegate iPad]) {
        [self performSegueWithIdentifier: @"showDetail" sender: self];
    }
    else
        [[iXolrAppDelegate singleton] gotoTopic:message.topic msgnum:message.msgnum_int];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([[segue identifier] isEqualToString:@"showDetail"]) {
        NSIndexPath *indexPath = [self.tableView indexPathForSelectedRow];
        CIXMessage *message = messages[indexPath.row];
        DetailViewController *vc = [DetailViewController findDetailViewFrom: segue];
        [vc gotoTopic:message.topic msgnum:message.msgnum_int];
    }
}

@end
