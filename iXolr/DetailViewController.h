//
//  DetailViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "TopSettingsVC.h"
#import "MessageEditViewController.h"
#import "ThreadedMessageListVC.h"

@class Topic;
@class CIXMessage;
@protocol GenericMessage;

@interface DetailViewController : UIViewController <UIWebViewDelegate, UISearchBarDelegate, SettingsViewControllerDelegate, MessageEditViewControllerDelegate, UIGestureRecognizerDelegate, UITextViewDelegate, MFMailComposeViewControllerDelegate, UIToolbarDelegate, ThreadedMessageListDelegate> {
@private
    NSMutableArray *lastVisited;
    UILabel *_toolbarTitle;
    BOOL buttonsVisible;
    BOOL hasAppeared;
}

+ (DetailViewController *) findDetailViewFrom: (UIStoryboardSegue *)segue;
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum;

@property (nonatomic, strong) IBOutlet UIToolbar *toolbar;
@property (nonatomic, strong) Topic *topic;
@property (nonatomic, strong) NSObject<GenericMessage> *currentMessage;
@property (nonatomic, strong) IBOutlet UIWebView *textWebView;
@property (nonatomic, strong) IBOutlet UITableView *messageTableView;
@property (nonatomic, strong) IBOutlet UILabel *toolbarTitle;
@property (strong, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) IBOutlet UIButton *searchButton;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *headerViewHeight;
@property (strong, nonatomic) IBOutlet NSLayoutConstraint *messageTableViewHeight;
@property (strong, nonatomic) IBOutlet UIView *lowerView;
@property (strong, nonatomic) IBOutlet UIView *headerView;
@property (strong, nonatomic) IBOutlet UILabel *headerLabel;
@property (strong, nonatomic) IBOutlet UIButton *starButton;
@property (strong, nonatomic) IBOutlet UIButton *editButton;
@property (strong, nonatomic) IBOutlet UIButton *lockButton;
@property (nonatomic, strong) IBOutlet UILabel *pullDownMessageLabel;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *actionBarButtonItem;
@property (strong, nonatomic) IBOutlet UIBarButtonItem *fastForwardButtonItem;
@property (strong, nonatomic) IBOutlet UIButton *fastForwardButton;
@property(weak, nonatomic, readonly) NSArray *keyCommands;

@end
