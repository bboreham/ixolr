//
//  SettingsViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 10/09/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CixRequest.h"

@interface SettingsViewController : UIViewController

@property (nonatomic, strong) NSDictionary *profileData;

@property (nonatomic, strong) IBOutlet UILabel *testLoginSuccessLabel;
@property (nonatomic, strong) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UIProgressView *topicProgress;

@end

