//
//  FontSizeVC.h
//  iXolr
//
//  Created by Bryan Boreham on 05/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface FontSizeVC : UITableViewController

+ (NSString*) nameFromSize: (double)size;   // Convert size into a simple name like 'Small' or 'Medium'

@end
