//
//  TopSettingsVC.h
//  iXolr
//
//  Created by Bryan Boreham on 28/11/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MessageUI/MFMailComposeViewController.h>

@protocol SettingsViewControllerDelegate;

@interface TopSettingsVC : UIViewController <UITableViewDataSource, UITableViewDelegate, MFMailComposeViewControllerDelegate>

@property (nonatomic, weak) id <SettingsViewControllerDelegate> delegate;
@property (strong, nonatomic) IBOutlet UILabel *appVersionLabel;

@end

@protocol SettingsViewControllerDelegate
- (void)settingsViewControllerFinished:(TopSettingsVC *)controller;
@end

@interface GUISettingsVC : UITableViewController

@end

@interface OptionSettingsVC : UITableViewController

@end
