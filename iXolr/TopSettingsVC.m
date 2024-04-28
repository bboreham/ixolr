//
//  TopSettingsVC.m
//  iXolr
//
//  Created by Bryan Boreham on 28/11/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "TopSettingsVC.h"
#import "iXolrAppDelegate.h"
#import "SettingsViewController.h"
#import "SignatureVC.h"
#import "DirectoryCategoryVC.h"
#import "FontSizeVC.h"
#import "AdvancedSettings.h"
#import "TableViewUtilities.h"

@implementation TopSettingsVC
@synthesize delegate;
@synthesize appVersionLabel;

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

    self.navigationItem.title = @"Settings";
    UIBarButtonItem *doneButton = [[UIBarButtonItem alloc] initWithTitle:@"Done" style:UIBarButtonItemStyleDone target:self action:@selector(doneButtonPressed:)];
    self.navigationItem.rightBarButtonItem = doneButton;
    
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSString *receiptURLString = [receiptURL path];
#if !DEBUG
    BOOL isBeta = ([receiptURLString rangeOfString:@"sandboxReceipt"].location != NSNotFound);
#endif
    appVersionLabel.text = [NSString stringWithFormat:@"iXolr %@ %@", [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"],
#if DEBUG
        @"debug build"
#else
        isBeta ? @"beta" : @"release"
#endif
    ];
}

- (void)viewWillAppear:(BOOL)animated
{
    [(self.view.subviews)[0] reloadData];
    [super viewWillAppear: animated];
}


- (IBAction)infoButtonPressed:(id)sender {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString: @"http://bryan.boreham.org/iXolr/iXolr_4_Settings.html"] options: @{} completionHandler: nil];
}

- (IBAction)doneButtonPressed:(id)sender {
    [delegate settingsViewControllerFinished:self];
}

#pragma mark - Bug Report

- (IBAction)bugReportPressed:(id)sender {
    NSString *logString = [[iXolrAppDelegate singleton] recentLogs];
    
    if([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailCont = [[MFMailComposeViewController alloc] init];
        mailCont.mailComposeDelegate = self;
        
        NSString* versionLabel = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
        UIDevice *device = [UIDevice currentDevice];
        [mailCont setSubject:[NSString stringWithFormat:@"Bug report from iXolr %@ on %@ iOS %@", versionLabel, device.model, device.systemVersion]];
        [mailCont setToRecipients:@[@"ixolr-support@bjarneco.net"]];
        [mailCont setMessageBody:[NSString stringWithFormat:@"[Please describe the symptoms here, and say what you were doing]\n\n%@", logString] isHTML:NO];
        
        [self presentViewController:mailCont animated:YES completion:nil];
    } else {
        [[iXolrAppDelegate singleton] displayErrorMessage:@"You must have email configured on this device in order to send a bug report." title:@"Unable to send email"];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table handling

enum {
    CIXAccountSection,
    GUISettingsSection,
    OptionsSettingsSection,
    AdvancedSection,
    ConfDirectorySection,
    BugReportSection,
    SectionCount
};

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ([iXolrAppDelegate singleton].CIXusername == nil)
        return 2;   // Authenticate and bug-report
    else
        return SectionCount;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    if (section == GUISettingsSection && [iXolrAppDelegate singleton].CIXusername == nil)
        section = BugReportSection; // Always allow bug report
    
    if (section == BugReportSection)
        return @"In case of emergency";
    else
        return nil;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    if (section == CIXAccountSection && [iXolrAppDelegate singleton].CIXusername == nil)
        return @"Before you can read messages with iXolr, \nyou must log in to CIX and allow access.";
    else
        return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"CellIdentifier";
	
	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = @"";

    NSInteger section = indexPath.section;
    if (section == GUISettingsSection && [iXolrAppDelegate singleton].CIXusername == nil)
        section = BugReportSection; // Always allow bug report

    switch (section) {
        case CIXAccountSection:
            cell.textLabel.text = @"CIX Account";
            if ([iXolrAppDelegate singleton].CIXusername == nil)
                cell.detailTextLabel.text = @"Not authenticated yet";
            else
                cell.detailTextLabel.text = [iXolrAppDelegate singleton].CIXusername;
            break;
        case GUISettingsSection:
            cell.textLabel.text = @"Visual Settings";
            break;
        case OptionsSettingsSection:
            cell.textLabel.text = @"Options";
            break;
        case AdvancedSection:
            cell.textLabel.text = @"Advanced Commands";
            break;
        case ConfDirectorySection:
            cell.textLabel.text = @"Conference Directory";
            break;
        case BugReportSection:
            cell.textLabel.text = @"Send Bug Report";
            cell.accessoryType = UITableViewCellAccessoryNone;
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];
    UIViewController *vc = nil;
    NSInteger section = indexPath.section;
    if (section == GUISettingsSection && [iXolrAppDelegate singleton].CIXusername == nil)
        section = BugReportSection; // Always allow bug report
    
    switch (section) {
        case CIXAccountSection: 
            vc = [[SettingsViewController alloc] initWithNibName:@"SettingsView" bundle:nil];
            break;
        case AdvancedSection: 
            vc = [[iXolrAdvancedSettings alloc] initWithStyle:UITableViewStyleGrouped];
            break;
        case GUISettingsSection:
            vc = [[GUISettingsVC alloc] initWithStyle:UITableViewStyleGrouped];
            break;
        case OptionsSettingsSection:
            vc = [[OptionSettingsVC alloc] initWithStyle:UITableViewStyleGrouped];
            break;
        case ConfDirectorySection: 
            vc = [[DirectoryCategoryVC alloc] initWithStyle:UITableViewStyleGrouped];
            break;
        case BugReportSection: {
            [self bugReportPressed:self];
        }
    }
    if (vc != nil) {
        [[self navigationController] pushViewController:vc animated:YES];
    }
}

@end

#pragma mark - GUI Settings View Controller

@implementation GUISettingsVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Visual Settings";
}

enum {
    ReflowTextSection,
    InlineImagesSection,
    ThreadHeadersVisibleSection,
    MyMessagesVisibleSection,
    MessageFontSizeSection,
    AnimationsOnSection,
    GUISectionCount
};

- (IBAction)reflowTextSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].reflowText = sender.on;
}

- (IBAction)inlineImagesSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].inlineImages = sender.on;
}

- (IBAction)useDynamicTypeswitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].useDynamicType = sender.on;
    [self insertOrDeletePath:[NSIndexPath indexPathForRow:1 inSection:MessageFontSizeSection] flag:!sender.on];
}

- (IBAction)messageFontSizeChanged:(UIStepper*)sender {
    [iXolrAppDelegate settings].messageFontSize = sender.value;
}

- (IBAction)threadsDefaultOpenSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].threadsDefaultOpen = sender.on;
}

- (IBAction)threadHeadersVisibleSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].threadHeadersVisible = sender.on;
    [self insertOrDeletePath:[NSIndexPath indexPathForRow:1 inSection:ThreadHeadersVisibleSection] flag:sender.on];
}

- (IBAction)myMessagesVisibleSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].myMessagesVisible = sender.on;
}

- (IBAction)animationsOnSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].animationsOn = sender.on;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return GUISectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == ThreadHeadersVisibleSection && [iXolrAppDelegate settings].threadHeadersVisible)
        return 2;
    else if (section == MessageFontSizeSection && ![iXolrAppDelegate settings].useDynamicType)
        return 2;
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *CellIdentifier = @"CellIdentifier";
	
	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [view dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
    }
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.accessoryView = nil;
    cell.detailTextLabel.text = nil;
    
    switch (indexPath.section) {
        case ReflowTextSection:
            cell.textLabel.text = @"Reflow Text";
            [self addSwitchToCell:cell selector:@selector(reflowTextSwitchChanged:) value:[iXolrAppDelegate settings].reflowText];
            break;
        case InlineImagesSection:
            cell.textLabel.text = @"Inline Images";
            [self addSwitchToCell:cell selector:@selector(inlineImagesSwitchChanged:) value:[iXolrAppDelegate settings].inlineImages];
            break;
        case ThreadHeadersVisibleSection:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Thread Headers";
                [self addSwitchToCell:cell selector:@selector(threadHeadersVisibleSwitchChanged:) value:[iXolrAppDelegate settings].threadHeadersVisible];
            } else {
                cell.textLabel.text = @"Threads Default Open";
                cell.indentationLevel = 1;
                [self addSwitchToCell:cell selector:@selector(threadsDefaultOpenSwitchChanged:) value:[iXolrAppDelegate settings].threadsDefaultOpen];
            }
            break;
        case MyMessagesVisibleSection:
            cell.textLabel.text = @"Show My Messages";
            [self addSwitchToCell:cell selector:@selector(myMessagesVisibleSwitchChanged:) value:[iXolrAppDelegate settings].myMessagesVisible];
            break;
        case MessageFontSizeSection:
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Dynamic Type";
                [self addSwitchToCell:cell selector:@selector(useDynamicTypeswitchChanged:) value:[iXolrAppDelegate settings].useDynamicType];
                break;
            } else {
            cell.textLabel.text = @"Message Text Size";
            cell.indentationLevel = indexPath.row;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.detailTextLabel.text = [FontSizeVC nameFromSize:[iXolrAppDelegate settings].messageFontSize];
            cell.detailTextLabel.font = [UIFont fontWithName: @"Helvetica" size:[iXolrAppDelegate settings].messageFontSize];
            break;
            }
        case AnimationsOnSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"Row Animations";
            [self addSwitchToCell:cell selector:@selector(animationsOnSwitchChanged:) value:[iXolrAppDelegate settings].animationsOn];
            break;
    }
    
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
    switch (section) {
        case MessageFontSizeSection:
            return @"Dynamic Type lets you set text size in iPhone Settings / General";
        default:
            return nil;
    }
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];
    UIViewController *vc = nil;
    switch (indexPath.section) {
        case MessageFontSizeSection:
            if (indexPath.row == 1)
                vc = [[FontSizeVC alloc] initWithStyle:UITableViewStyleGrouped];
            break;
    }
    if (vc != nil) {
        [[self navigationController] pushViewController:vc animated:YES];
    }
}

@end

#pragma mark - Option Settings View Controller

@implementation OptionSettingsVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Options Settings";
}

enum {
    SignatureSection,
    AutoSyncSection,
    MyMessagesAutoreadSection,
    //AutoUploadSection,
    UploadReadStatusSection,
    UploadStarsSection,
    OutboxAlertSection,
    TimeoutSection,
    ShowMessageToolbarSection,
    OptionsSectionCount
};

- (IBAction)autoSyncSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].autoSync = sender.on;
    [self insertOrDeletePath:[NSIndexPath indexPathForRow:1 inSection:AutoSyncSection] flag:sender.on];
}

- (IBAction)uploadReadStatusSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].uploadReadStatus = sender.on;
}

- (IBAction)uploadStarsSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].uploadStars = sender.on;
}

- (IBAction)myMessagesAutoreadSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].myMessagesAutoread = sender.on;
}

- (IBAction)autoUploadSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].autoUpload = sender.on;
}

- (IBAction)outboxAlertSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].outboxAlert = sender.on;
    [self insertOrDeletePath:[NSIndexPath indexPathForRow:1 inSection:OutboxAlertSection] flag:sender.on];
}

- (IBAction)outboxAlertSliderChanged:(UISlider*)sender {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:OutboxAlertSection]];
    float minutes = sender.value;
    cell.textLabel.text = [NSString stringWithFormat: @"After %.0f minute%s:", minutes, (minutes > 0.49 && minutes < 1.51) ? "" : "s"];
    [iXolrAppDelegate settings].outboxAlertMinutesDelay = sender.value;
}

- (IBAction)showMessageToolbarSwitchChanged:(UISwitch*)sender {
    [iXolrAppDelegate settings].showMessageToolbar = sender.on;
}

- (IBAction)timeoutSliderChanged:(UISlider*)sender {
    UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:TimeoutSection]];
    float minutes = sender.value;
    cell.textLabel.text = [NSString stringWithFormat: @"Network timeout %.0f min%s", minutes, (minutes > 0.49 && minutes < 1.51) ? "" : "s"];
    [iXolrAppDelegate settings].timeoutSecs = sender.value * 60;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Last option - toolbar - is only available on iPhone
    return [iXolrAppDelegate iPad] ? OptionsSectionCount - 1 : OptionsSectionCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == AutoSyncSection && [iXolrAppDelegate settings].autoSync)
        return 2;
    else if (section == OutboxAlertSection && [iXolrAppDelegate settings].outboxAlert)
        return 2;
    else
        return 1;
}

- (UITableViewCell *)tableView:(UITableView *)view cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Don't bother trying to re-use cells as they are all very different
    UITableViewCell *cell = nil;
    
    switch (indexPath.section) {
        case SignatureSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:nil];
            cell.textLabel.text = @"Signature";
            cell.detailTextLabel.text = [iXolrAppDelegate settings].signature;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case AutoSyncSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Automatic Sync";
                [self addSwitchToCell:cell selector:@selector(autoSyncSwitchChanged:) value:[iXolrAppDelegate settings].autoSync];
            } else {
                cell.textLabel.text = @"Auto-upload Outbox";
                cell.indentationLevel = 1;
                [self addSwitchToCell:cell selector:@selector(autoUploadSwitchChanged:) value:[iXolrAppDelegate settings].autoUpload];
            }
            break;
        case UploadReadStatusSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"Upload Read Status";
            [self addSwitchToCell:cell selector:@selector(uploadReadStatusSwitchChanged:) value:[iXolrAppDelegate settings].uploadReadStatus];
            break;
        case UploadStarsSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"Upload Message Stars";
            [self addSwitchToCell:cell selector:@selector(uploadStarsSwitchChanged:) value:[iXolrAppDelegate settings].uploadStars];
            break;
        case MyMessagesAutoreadSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            cell.textLabel.text = @"My messages marked read";
            [self addSwitchToCell:cell selector:@selector(myMessagesAutoreadSwitchChanged:) value:[iXolrAppDelegate settings].myMessagesAutoread];
            break;
        case OutboxAlertSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Alert un-sent messages";
                [self addSwitchToCell:cell selector:@selector(outboxAlertSwitchChanged:) value:[iXolrAppDelegate settings].outboxAlert];
            } else {
                float minutes = [iXolrAppDelegate settings].outboxAlertMinutesDelay;
                cell.textLabel.text = [NSString stringWithFormat: @"After %.0f minute%s:", minutes, (minutes > 0.49 && minutes < 1.51) ? "" : "s"];
                cell.indentationLevel = 1;
                [self addSliderToCell:cell selector:@selector(outboxAlertSliderChanged:) value:minutes min:0 max:20];
            }
            break;
        case ShowMessageToolbarSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Toolbar in message view";
                cell.textLabel.adjustsFontSizeToFitWidth = YES;
                [self addSwitchToCell:cell selector:@selector(showMessageToolbarSwitchChanged:) value:[iXolrAppDelegate settings].showMessageToolbar];
            }
            break;
        case TimeoutSection:
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
            float minutes = [iXolrAppDelegate settings].timeoutSecs / 60;
            cell.textLabel.adjustsFontSizeToFitWidth = YES;
            cell.textLabel.text = [NSString stringWithFormat: @"Network timeout %.0f min%s", minutes, (minutes > 0.49 && minutes < 1.51) ? "" : "s"];
            [self addSliderToCell:cell selector:@selector(timeoutSliderChanged:) value:minutes min:1 max:9];
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [aTableView deselectRowAtIndexPath:indexPath animated:NO];
    UIViewController *vc = nil;
    switch (indexPath.section) {
        case SignatureSection: 
            vc = [[SignatureVC alloc] initWithNibName:@"SignatureView" bundle:nil];
            break;
    }
    if (vc != nil) {
        [[self navigationController] pushViewController:vc animated:YES];
    }
}



@end
