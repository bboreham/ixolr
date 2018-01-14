//
//  SettingsViewController.m
//  iXolr
//
//  Created by Bryan Boreham on 10/09/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "SettingsViewController.h"
#import "iXolrAppDelegate.h"
#import "TableViewUtilities.h"
#import "LoginViewController.h"

@implementation SettingsViewController
{
    LoginViewController *_loginVC;
    UILabel *testLoginSuccesLabel;
    UITableView *tableView;
}

@synthesize testLoginSuccessLabel;
@synthesize tableView;
@synthesize topicProgress;
@synthesize profileData;


- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.navigationItem.title = @"CIX Account";
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleLoginStatus:) name:@"loginStatus" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleRefreshFinished:) name:@"topicInfoFinished" object:nil];
    
    testLoginSuccessLabel.text = @"";
    [self requestCIXProfile];
}

- (void)viewDidUnload
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self setTestLoginSuccessLabel:nil];
    [self setTableView:nil];
    [self setTopicProgress:nil];
    [self setAuthenticateButton:nil];
    [self setJoinIXolrConfButton:nil];
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
	return YES;
}

#pragma mark - Table handling

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (profileData == nil)
        return 1;
    else
        return 3;
}

- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"CellIdentifier";
	
	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        //cell.textLabel.font = [UIFont fontWithName:@"Helvetica" size:15.0];
    }
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Username";
            if ([iXolrAppDelegate singleton].CIXusername == nil)
                cell.detailTextLabel.text = @"Not authenticated yet";
            else
                cell.detailTextLabel.text = [iXolrAppDelegate singleton].CIXusername;
            break;
            
        case 1:
            cell.textLabel.text = @"Name";
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ %@", profileData[@"Fname"], profileData[@"Sname"]];
            break;
            
        case 2:
            cell.textLabel.text = @"Email";
            cell.detailTextLabel.text = profileData[@"Email"];
            break;
    }

    return cell;
}

#pragma mark - Action Buttons

- (IBAction)clearAuthenticationPressed:(id)sender {
    [[iXolrAppDelegate singleton] receiveAccessToken: @""];
    self.profileData = nil;
    [iXolrAppDelegate singleton].CIXusername = nil;
    [[iXolrAppDelegate singleton] saveState];
    NSLog(@"Cleared all authentication info");
    [tableView reloadData];
}

- (IBAction)joinIXolrConfButtonPressed:(id)sender {
    [[iXolrAppDelegate singleton] joinConference:@"ixolr"];
}

#pragma mark - Login Process

// User has pressed the 'Authenticate with CIX' button: start the OAuth process
- (IBAction)testLoginButtonPressed:(id)sender {
    testLoginSuccessLabel.text = @"Requesting...";
    _loginVC = [[LoginViewController alloc] initWithNibName:@"LoginView" bundle:nil];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_loginVC requestRequestToken: self.navigationController];
}

// Attempt to request the currently-authorized CIX user's profile, but return NO if there is no authorization
- (BOOL) requestCIXProfile {
    return [[iXolrAppDelegate singleton] requestCIXProfileWithCompletion:^(NSDictionary* results){
        self.profileData = results;
        [iXolrAppDelegate singleton].CIXusername = profileData[@"Uname"];
        NSLog(@"CIX username returned in profile: %@", [iXolrAppDelegate singleton].CIXusername);
        [tableView reloadData];
    }];
}

- (void)handleLoginStatus:(NSNotification*)param
{
    NSError *error = [param object];
    NSString *msg = nil;
    if (error == nil)
    {
        msg = @"Successfully authenticated";
        [self requestCIXProfile];
        if ([iXolrAppDelegate singleton].CIXusername == nil) { // first-time init
            [iXolrAppDelegate singleton].downloadSince = [NSDate dateWithTimeIntervalSinceNow:-10*24*60*60]; // set back 10 days
            [[iXolrAppDelegate singleton] refreshTopicList];
        }
    }
    else
    {
        NSInteger code = [error code];	
        
        if (code == NSURLErrorNetworkConnectionLost || code == NSURLErrorNotConnectedToInternet) {
            msg = NSLocalizedString(@"No network connection.", @"Network down.");
        } else if (code == NSURLErrorTimedOut) {
            msg = NSLocalizedString(@"Connection timed out, try again in a minute.", @"Connection fail");
        } else if (code >= 500) {
            msg = NSLocalizedString(@"CIX is overloaded, try again in a minute.", @"API fail");
        } else if (code < 0) {
            msg = NSLocalizedString(@"An internal error has occurred; please contact support", @"Internal fail");
        } else {
            msg = NSLocalizedString(@"CIX rejected the authentication. Please check your username and password.", @"Failed to authenticate user");
        }
	}
    
    testLoginSuccessLabel.text = msg;
}

- (void)handleRefreshFinished:(NSNotification*)param
{
    testLoginSuccessLabel.text = @"Setup complete";
    [[iXolrAppDelegate singleton] doSync:self];
}
@end
