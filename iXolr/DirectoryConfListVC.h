//
//  DirectoryConfListVC.h
//  iXolr
//
//  Created by Bryan Boreham on 03/12/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DirectoryConfListVC : UITableViewController <UIAlertViewDelegate> {
@private
NSArray *_categories;
}

@property (nonatomic, strong) NSString* categoryName;

@end
