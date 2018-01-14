//
//  FontSizeVC.m
//  iXolr
//
//  Created by Bryan Boreham on 05/02/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "FontSizeVC.h"
#import "iXolrAppDelegate.h"

@implementation FontSizeVC

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Message Text Size";
}

#pragma mark - Table view data source

static int font_sizes[] = {10, 13, 15, 17, 20};
static NSString* font_names[] = {@"Tiny", @"Small", @"Medium", @"Large", @"Huge"};
static int num_fonts = sizeof(font_sizes) / sizeof(font_sizes[0]);

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return num_fonts;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

+ (NSString*) nameFromSize: (double)size
{
    for (int i = 0; i < num_fonts; ++i)
        if (size-0.001 < font_sizes[i])
            return font_names[i];
    return @"Unknown";
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"FontSizeCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    
    cell.detailTextLabel.font = [UIFont fontWithName: @"Helvetica" size:font_sizes[indexPath.section]];
    cell.textLabel.text = [FontSizeVC nameFromSize:cell.detailTextLabel.font.pointSize];
    cell.detailTextLabel.text = @"Sample";
    
    if (fabs(cell.detailTextLabel.font.pointSize - [iXolrAppDelegate settings].messageFontSize) < 0.001)
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:NO];
    [iXolrAppDelegate settings].messageFontSize = [tableView cellForRowAtIndexPath:indexPath].detailTextLabel.font.pointSize;
    [tableView reloadData];
}

@end
