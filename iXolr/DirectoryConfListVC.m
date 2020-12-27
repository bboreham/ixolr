//
//  DirectoryConfListVC.m
//  iXolr
//
//  Created by Bryan Boreham on 03/12/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "DirectoryConfListVC.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"
#import "TableViewUtilities.h"

@implementation DirectoryConfListVC

@synthesize categoryName;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.title = self.categoryName;
    _categories = nil;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDirectoryCategoryForums:) name:@"directoryCategoryForums" object:nil];
}

// App Delegate has finished loading directory data
- (void)handleDirectoryCategoryForums:(NSNotification*)param
{
    _categories = [param object];
    [self.tableView reloadData];
}

- (IBAction)joinButtonPressed:(UISwitch*)sender {
}

#pragma mark - Table view

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (_categories == nil || [_categories count] == 0)
        return 1;
    else
        return [_categories count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (_categories == nil || [_categories count] == 0)
        return 0;
    CIXSubCategory *cat = _categories[section];
    return [cat.forums count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (_categories == nil)
        return @"Fetching data...";
    else if ([_categories count] == 0)
        return @"No conferences in this category";
    CIXSubCategory *cat = _categories[section];
    return cat.name;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    CIXSubCategory *cat = _categories[indexPath.section];
    NSDictionary *fields = (cat.forums)[indexPath.row];
    NSInteger numRecent = [fields[@"Recent"] integerValue];
    NSString *activityLevel = @"  💤";
    if (numRecent > 100)
        activityLevel = @"  🔥🔥🔥";
    else if (numRecent > 10)
        activityLevel = @"  🔥";
    cell.textLabel.text = [fields[@"Forum"] stringByAppendingString:activityLevel];
    cell.detailTextLabel.text = fields[@"Title"];

    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CIXSubCategory *cat = _categories[indexPath.section];
    NSString *confName = [(cat.forums)[indexPath.row] valueForKey:@"Forum"];
    NSString *str = [NSString stringWithFormat:@"Do you want to join conference %@?", confName];
    [UIAlertController showWithTitle:@"Confirm Join" message:str actionTitle:@"Join" cancelTitle:@"Cancel" from:self ifConfirmed:^{
        [[iXolrAppDelegate singleton] joinConference: confName];
    }];
}
@end
