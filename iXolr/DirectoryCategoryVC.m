//
//  DirectoryCategoryVC.m
//  iXolr
//
//  Created by Bryan Boreham on 03/12/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "DirectoryCategoryVC.h"
#import "iXolrAppDelegate.h"
#import "DirectoryConfListVC.h"
#import "DataController.h"

@implementation DirectoryCategoryVC

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

    //Add the search bar
    UISearchBar *searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0,0,self.view.frame.size.width,44)];
    searchBar.delegate = self;
    searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
    searchBar.autocapitalizationType = UITextAutocapitalizationTypeNone;
    searchBar.placeholder = @"Search the entire directory";
    self.tableView.tableHeaderView = searchBar;    

    self.title = @"Categories";
    [[iXolrAppDelegate singleton] requestDirectoryCategories];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDirectoryCategories:) name:@"directoryCategories" object:nil];
}

// App Delegate has finished loading top-level data
- (void)handleDirectoryCategories:(NSNotification*)param
{
    _categories = [param object];
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_categories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
    }
    
    CIXCategory *cat = _categories[indexPath.row];
    cell.textLabel.text = cat.name;
    cell.detailTextLabel.text = [cat.subCategories componentsJoinedByString:@", "];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CIXCategory *cat = _categories[indexPath.row];
    // Send the http request that the new view will receive the results from.  Bit of a race condition here between setting up the view and receiving the results.
    if (![[iXolrAppDelegate singleton] requestDirectoryForCategory:cat.name]) {
        [[iXolrAppDelegate singleton] displayErrorTitle:@"Service Failure" message:@"CIX is unable to process this category name"];
        return;
    }
    // Create and push another view controller.
    DirectoryConfListVC *directoryConfListVC = [[DirectoryConfListVC alloc] initWithStyle:UITableViewStyleGrouped];
    directoryConfListVC.categoryName = cat.name;
    [[self navigationController] pushViewController:directoryConfListVC animated:YES];
}

#pragma mark - Search Bar delegate

- (BOOL)searchBarShouldBeginEditing:(UISearchBar *)searchBar
{
    searchBar.showsCancelButton = YES;
    return YES;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    searchBar.text = @"";
    [searchBar resignFirstResponder];       
    searchBar.showsCancelButton = NO;
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    // Send the http request that the new view will receive the results from.  Bit of a race condition here between setting up the view and receiving the results.
    [[iXolrAppDelegate singleton] requestDirectorySearch:searchBar.text];
    // Create and push another view controller.
    DirectoryConfListVC *directoryConfListVC = [[DirectoryConfListVC alloc] initWithStyle:UITableViewStyleGrouped];
    directoryConfListVC.categoryName = [NSString stringWithFormat: @"Search Results for %@", searchBar.text];
    [[self navigationController] pushViewController:directoryConfListVC animated:YES];
}

@end
