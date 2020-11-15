//
//  AdvancedSettings.m
//  iXolr
//
//  Created by Bryan Boreham on 06/11/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "AdvancedSettings.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "TableViewUtilities.h"
#import "StringUtils.h"

// Forward declarations of private methods
@interface iXolrAdvancedSettings ()
- (IBAction)markReadValueChanged:(id)sender;
@end

@implementation iXolrAdvancedSettings

#pragma mark - View lifecycle


- (void)viewDidLoad
{
    [super viewDidLoad];
    self.navigationItem.title = @"Advanced Commands";
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

- (void)markReadOlder:(NSInteger) days {
    iXolrAppDelegate *app = [iXolrAppDelegate singleton];
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-(60*60*24)*days];
    NSString *str = @"Mark as read all messages older than this?";
    [app opTitle:str buttonTitle:@"Mark Read Older" start:startDate mode:UIDatePickerModeDateAndTime
     ifConfirmedFrom:self Rect:[self.tableView rectForSection:MarkReadSection] goBlock:^(NSDate *date) {
        [[iXolrAppDelegate singleton].dataController markReadOlderThanDate: date];
    }];
}

#pragma mark - Table view data source

enum {
    SyncWithCoSySection,
    SetDownloadSection,
    MarkReadSection,
    PurgeMessagesSection,
    CompactDBSection,
    RefreshTopicListSection,
    AdvancedSectionCount
};

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return AdvancedSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (NSString*)stringForDays:(NSInteger)days {
    return [NSString stringWithFormat:@"%ld day%s", (long)days, days!=1 ? "s":""];
}

- (IBAction)markReadValueChanged:(UISlider*)sender {
    NSInteger days = sender.value;
    [iXolrAppDelegate settings].markReadDays = days;
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:MarkReadSection]];
    cell.detailTextLabel.text = [self stringForDays:days];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    NSString *title = nil;
    switch (section) {
        case SetDownloadSection:
            title = @"Set the time from which iXolr will download messages at CIX when you next sync.";
            break;
        case MarkReadSection:
            title = @"Mark as read the downloaded copy of messages older than this time. Does not affect read status on CIX";
            break;
        case PurgeMessagesSection:
            title = @"Erase threads older than a specified date from this device";
            break;
        case CompactDBSection:
            title = @"Compact the database on this device, to save space";
            break;
        case RefreshTopicListSection:
            title = @"Re-fetch the list of all topics your CIX account is joined to. Excludes topics which have had no messages recently";
            break;
        case SyncWithCoSySection:
            title = @"Update read status from the underlying CIX system. If you use another OLR such as Ameol then this will mark messages read in iXolr if they have been downloaded by your OLR.";
            break;
    }
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"CellIdentifier";
	
	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    
    switch (indexPath.section) {
        case SetDownloadSection:
            cell.textLabel.text = @"Set download timestamp";
            cell.detailTextLabel.text = [[iXolrAppDelegate singleton].downloadSince asStringWith:@"Currently: %@"];
            break;
        case MarkReadSection:
            cell.textLabel.text = @"Mark read older than";
            [self addSliderToCell:cell selector:@selector(markReadValueChanged:) value:[iXolrAppDelegate settings].markReadDays min:0.0f max:30.0f];
            cell.detailTextLabel.text = [self stringForDays:[iXolrAppDelegate settings].markReadDays];
            break;
        case PurgeMessagesSection:
            cell.textLabel.text = @"Purge old messages";
            break;
        case CompactDBSection:
            cell.textLabel.text = @"Compact database";
            break;
        case RefreshTopicListSection:
            cell.textLabel.text = @"Refresh topic list";
            break;
        case SyncWithCoSySection:
            cell.textLabel.text = @"Sync with CoSy";
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];
    switch (indexPath.section) {
        case SetDownloadSection: {
            iXolrAppDelegate *app = [iXolrAppDelegate singleton];
            NSString *str = @"Set back the download timestamp, so future downloads will start from that point";
            [app opTitle:str buttonTitle:@"Set download timestamp" start:app.downloadSince mode:UIDatePickerModeDateAndTime ifConfirmedFrom:self Rect:[aTableView rectForRowAtIndexPath:indexPath] goBlock:^(NSDate *date) {
                app.downloadSince = date;
                NSLog(@"Set downloadSince to %@", date);
                [aTableView beginUpdates];
                [aTableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
                [aTableView endUpdates];
            }];
            break;
        }
        case MarkReadSection:
            [self markReadOlder:[iXolrAppDelegate settings].markReadDays];
            break;
        case PurgeMessagesSection:
            [[iXolrAppDelegate singleton] purgeIfConfirmedFrom:self Rect:[aTableView rectForRowAtIndexPath:indexPath] ];
            break;
        case CompactDBSection:
        {
            [UIAlertView showWithTitle:@"Confirm Compaction" message:@"Please confirm you want to compact the database file?" completionBlock:^(NSUInteger buttonIndex) {
                if (buttonIndex == 1)
                {
                    [[[iXolrAppDelegate singleton] dataController] VacuumStore];
                }
            } cancelButtonTitle:@"Cancel" otherButtonTitles:@"Compact", nil];
            break;
        }
            break;
        case RefreshTopicListSection:
            [[iXolrAppDelegate singleton] refreshTopicList];
            break;
        case SyncWithCoSySection:
        {
            [UIAlertView showWithTitle:@"Confirm Sync" message:@"Do you want to sync the unread status of all messages with CIX?" completionBlock:^(NSUInteger buttonIndex) {
                if (buttonIndex == 1)
                {
                    [[iXolrAppDelegate singleton] cosySync: YES];
                }
            } cancelButtonTitle:@"Cancel" otherButtonTitles:@"Sync", nil];
            break;
        }
    }
}

@end
