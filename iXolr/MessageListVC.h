//
//  MessageListVC.h
//  iXolr
//
//  Created by Bryan Boreham on 01/01/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MessageEditViewController.h"

@interface MessageListVC : UITableViewController 

- (UITableViewCell *)tableViewCellWithReuseIdentifier:(NSString *)identifier;
- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath;

@property (nonatomic, strong) NSArray *messages;

@end
