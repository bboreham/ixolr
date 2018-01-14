//
//  RootViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TopSettingsVC.h"

@class Conference;
@class Topic;

@interface RootViewController : UITableViewController <UISearchDisplayDelegate, UISearchBarDelegate, SettingsViewControllerDelegate>

@property (strong, nonatomic) NSArray *conferences;
@property (nonatomic, strong) IBOutlet UIProgressView *progressView;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *fastForwardBtn;

- (void)gotoConference:(Conference*)conf;
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum;
- (void)switchSubViewToTopic: (Topic*)topic;
- (UIViewController*)createTopicViewController:(Conference*)conf;
- (void)switchSubViewToOutbox;

@end
