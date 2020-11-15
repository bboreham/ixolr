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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
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
    cell.textLabel.text = [(cat.forums)[indexPath.row] valueForKey:@"Forum"];
    cell.detailTextLabel.text = [(cat.forums)[indexPath.row] valueForKey:@"Title"];
    NSInteger numRecent = [[(cat.forums)[indexPath.row] valueForKey:@"Recent"] integerValue];
    if (numRecent > 100)
        cell.imageView.image = [UIImage imageNamed:@"bright_sun.png"];
    else if (numRecent > 10)
        cell.imageView.image = [UIImage imageNamed:@"dim_sun.png"];
    else if (numRecent > 0)
        cell.imageView.image = [UIImage imageNamed:@"moon.png"];
    else
        cell.imageView.image = [UIImage imageNamed:@"clear.png"];
                                
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CIXSubCategory *cat = _categories[indexPath.section];
    NSString *confName = [(cat.forums)[indexPath.row] valueForKey:@"Forum"];
    NSString *str = [NSString stringWithFormat:@"Do you want to join conference %@?", confName];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Confirm Join" message:str delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Join", nil];
	[alert show];
}

#pragma mark - Alert view delegate

- (void)alertView:(UIAlertView*)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 1) {
        NSIndexPath *indexPath = self.tableView.indexPathForSelectedRow;
        CIXSubCategory *cat = _categories[indexPath.section];
        NSString *confName = [(cat.forums)[indexPath.row] valueForKey:@"Forum"];
        [[iXolrAppDelegate singleton] joinConference: confName];
    }
}

@end
