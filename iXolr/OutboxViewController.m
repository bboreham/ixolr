//
//  OutboxViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 25/09/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "OutboxViewController.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "Message.h"
#import "Topic.h"
#import "TableViewUtilities.h"
#import "MessageEditViewController.h"

@implementation OutboxViewController

- (NSString*)keyPathForMessages
{
    return @"outboxMessages";
}

#pragma mark - View lifecycle

#define ROW_HEIGHT 52

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.navigationItem.title = @"Outbox";
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
	self.tableView.rowHeight = ROW_HEIGHT;
}

#define IMAGE_TAG 3

- (UITableViewCell *)tableViewCellWithReuseIdentifier:(NSString *)identifier {
    UITableViewCell *cell = [super tableViewCellWithReuseIdentifier:identifier];
    cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    cell.indentationWidth = 26;
    cell.indentationLevel = 1;
    
	// Create an image view for the lock image.
	CGRect rect = CGRectMake(5, 18, 24, 24);
    
	UIImageView *imageView = [[UIImageView alloc] initWithFrame:rect];
	imageView.tag = IMAGE_TAG;
	[cell.contentView addSubview:imageView];

    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    [super configureCell:cell atIndexPath:indexPath];

    CIXMessage *message = (self.messages)[indexPath.row];
	// Set the image.
	UIImageView *imageView = (UIImageView *)[cell viewWithTag:IMAGE_TAG];
	imageView.image = message.isHeld ? [UIImage imageNamed:@"lock.png"] : nil;
}

// User has hit 'edit' and made some change
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        CIXMessage *message = (self.messages)[indexPath.row];
        [[iXolrAppDelegate singleton].dataController deleteMessage:message];
        [[iXolrAppDelegate singleton].dataController saveContext];
    }   
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    CIXMessage *message = (self.messages)[indexPath.row];
        
    [MessageEditViewController popupMessageEdit:message commentTo:[message.topic messageWithNumber:message.commentTo] from:self delegate:self];
}

// Callback from message edit window
- (void)messageEditViewControllerConfirmed:(MessageEditViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
    [[iXolrAppDelegate singleton].dataController saveContext];  // Commit to database
    NSUInteger row = [self.messages indexOfObject:controller.message];
    if (row != NSNotFound)
    {
        NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:0];
        [self configureCell:[self.tableView cellForRowAtIndexPath:path] atIndexPath:path];
    }
    [[iXolrAppDelegate singleton] gotoTopic:controller.message.topic msgnum:controller.message.msgnum_int];
}

- (void)messageEditViewControllerCancelled:(MessageEditViewController *)controller
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

@end
