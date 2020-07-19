//
//  FavouritesVC.m
//  iXolr
//
//  Created by Bryan Boreham on 01/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FavouritesVC.h"
#import "Message.h"
#import "Topic.h"
#import "Conference.h"
#import "TableViewUtilities.h"

@implementation FavouritesVC

- (NSString*)keyPathForMessages
{
    return @"favouriteMessages";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Starred";
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    CIXMessage *message = (self.messages)[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@/%@:%d - %@", message.topic.conference.name, message.topic.name, message.msgnum_int, message.author];
    cell.detailTextLabel.text = message.firstLine;
}

@end


@implementation MyMessagesVC

- (NSString*)keyPathForMessages
{
    return @"myMessages";
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"My Messages";
    self.tableView.rowHeight = 64;
}

#define DATE_LABEL_TAG 123

- (UITableViewCell *)tableViewCellWithReuseIdentifier:(NSString *)identifier {
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:identifier];
    UILabel *label = [[UILabel alloc] initWithFrame: CGRectMake(self.view.frame.size.width-102, 3, 96, 16)];
    label.font = [UIFont systemFontOfSize:14];
    label.textColor = grayTextColor();
    label.textAlignment = NSTextAlignmentRight;
    label.tag = DATE_LABEL_TAG;
    [cell.contentView insertSubview:label atIndex:0];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    id<GenericMessage> message = (self.messages)[indexPath.row];
    cell.textLabel.text = [NSString stringWithFormat:@"%@/%@", message.topic.conference.name, message.topic.name];
    ((UILabel*)[cell viewWithTag:DATE_LABEL_TAG]).text = message.dateString;
    cell.detailTextLabel.text = message.firstLine;
    cell.detailTextLabel.numberOfLines = 0;
}

@end
