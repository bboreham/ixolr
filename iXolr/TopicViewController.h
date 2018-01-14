//
//  TopicViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 31/05/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

@class DetailViewController;
@class Topic;
@class Conference;

@interface TopicViewController : UITableViewController <UIAlertViewDelegate> {
}

@property (nonatomic, strong) NSArray *topicsArray;

@property (nonatomic, strong) Conference *conference;
@property (nonatomic, strong) Topic *currentTopic;

- (void) configureTitle;
- (void)squishButtonPressed:(id)sender;
- (void)pushDetailViewControllerTopic:(Topic*)topic msgnum:(NSInteger)msgnum;

@end
