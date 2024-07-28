//
//  iXolrAppDelegate.m
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "iXolrAppDelegate.h"

#import "RootViewController.h"
#import "DetailViewController.h"
#import "DataController.h"
#import "CixRequest.h"
#import "OAConsumer.h"
#import "Reachability.h"
#import "Conference.h"
#import "Message.h"
#import "Topic.h"
#import "Parser.h"
#import "SAMKeychain.h"
#import "TableViewUtilities.h"
#import "StringUtils.h"
#import "MBProgressHUD/MBProgressHUD.h"

@implementation iXolrAppDelegate
{
    OAConsumer				*consumer;
    NSString                *_authStr;
    NSTimer                 *_refreshTimer;
    Reachability            *_CIXhostReach;
    NSMutableSet            *_pendingMarkRead, *_pendingMarkUnread;
    NSMutableSet            *_pendingStar, *_pendingUnstar;
    UNNotificationRequest   *_notification;
    BOOL                    _badgeAllowed;
    NSOperationQueue        *_queueForMessageParsing;
    NSOperation             *_activationOp;
    CixRequestManager       *_CIXRequestManager;
    DDFileLogger            *_fileLogger;
    BOOL useBetaAPI, haveFixedKeychainAccessibility, backgroundFetchActive;
    MBProgressHUD *_popup_hud;  // Used to pop up a 'please wait' alert
    UIDatePickerPopover     *_popover; // hold popover reference until after callback
}

@synthesize window=_window;
@synthesize conferenceListViewController=_conferenceListViewController;
@synthesize detailViewController=_detailViewController;
@synthesize dataController=_dataController;
@synthesize settings=_settings;
@synthesize CIXusername=_CIXusername;
@synthesize lastRefreshed=_lastRefreshed;
@synthesize downloadSince=_downloadSince;
@synthesize threadWindowSize=_threadWindowSize;
@synthesize currentConferenceName=_currentConferenceName;
@synthesize currentTopicName=_currentTopicName;

@synthesize consumer;

NSString * const IXSettingUseDynamicType = @"useDynamicType";

+ (iXolrAppDelegate*) singleton
{
    if (![NSThread isMainThread])
        NSLog(@"iXolrAppDelegate singleton called on non-main thread");
    return (iXolrAppDelegate*)UIApplication.sharedApplication.delegate;
}

+ (iXolrSettings*) settings
{
    return [self singleton].settings;
}

+ (BOOL) iPad
{
    return [UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad;
}

#pragma mark - Lifecycle Management

- (void)restoreState 
{
    if (_settings == nil)
        _settings = [[iXolrSettings alloc] init];
    [self.settings restoreState];
    self.CIXusername = [[NSUserDefaults standardUserDefaults] stringForKey:@"CIXusername"];
    NSTimeInterval interval = [[NSUserDefaults standardUserDefaults] doubleForKey:@"lastRefreshed"];
    if (interval != 0)
        self.lastRefreshed = [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
    interval = [[NSUserDefaults standardUserDefaults] doubleForKey:@"downloadSince"];
    if (interval != 0)
        self.downloadSince = [NSDate dateWithTimeIntervalSinceReferenceDate:interval];
    else
        self.downloadSince = [self.lastRefreshed dateByAddingTimeInterval:-60];
    self.threadWindowSize = [[NSUserDefaults standardUserDefaults] floatForKey:@"threadWindowSize"];
    self.currentConferenceName = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentConferenceName"];
    self.currentTopicName = [[NSUserDefaults standardUserDefaults] stringForKey:@"currentTopicName"];
    if (self.settings.uploadReadStatus) {
        [_pendingMarkRead   addObjectsFromArray: [[NSUserDefaults standardUserDefaults] arrayForKey:@"pendingMarkRead"]];
        [_pendingMarkUnread addObjectsFromArray: [[NSUserDefaults standardUserDefaults] arrayForKey:@"pendingMarkUnread"]];
    }
    if (self.settings.uploadStars) {
        [_pendingStar       addObjectsFromArray: [[NSUserDefaults standardUserDefaults] arrayForKey:@"pendingStar"]];
        [_pendingUnstar     addObjectsFromArray: [[NSUserDefaults standardUserDefaults] arrayForKey:@"pendingUnstar"]];
    }
    //useBetaAPI = YES;
}

- (void)saveState 
{
    [self.dataController saveContext];
    [self.settings saveState];
    [[NSUserDefaults standardUserDefaults] setObject:self.CIXusername forKey:@"CIXusername"];
    [[NSUserDefaults standardUserDefaults] setDouble:[self.lastRefreshed timeIntervalSinceReferenceDate] forKey:@"lastRefreshed"];
    [[NSUserDefaults standardUserDefaults] setDouble:[self.downloadSince timeIntervalSinceReferenceDate] forKey:@"downloadSince"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.threadWindowSize forKey:@"threadWindowSize"];
    [[NSUserDefaults standardUserDefaults] setObject:self.currentConferenceName forKey:@"currentConferenceName"];
    [[NSUserDefaults standardUserDefaults] setObject:self.currentTopicName forKey:@"currentTopicName"];
    [[NSUserDefaults standardUserDefaults] setInteger:haveFixedKeychainAccessibility forKey:@"haveFixedKeychainAccessibility"];
    [[NSUserDefaults standardUserDefaults] setObject:[_pendingMarkRead   allObjects] forKey:@"pendingMarkRead"];
    [[NSUserDefaults standardUserDefaults] setObject:[_pendingMarkUnread allObjects] forKey:@"pendingMarkUnread"];
    [[NSUserDefaults standardUserDefaults] setObject:[_pendingStar       allObjects] forKey:@"pendingStar"];
    [[NSUserDefaults standardUserDefaults] setObject:[_pendingUnstar     allObjects] forKey:@"pendingUnstar"];
}

- (BOOL)application:(UIApplication *)application shouldSaveSecureApplicationState:(NSCoder *)coder
{
    [coder encodeInt:8 forKey:@"iXolrEncodingVersion"];
    [coder encodeInt:[iXolrAppDelegate iPad]+3 forKey:@"iXolrIPadVersion"];
    return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreSecureApplicationState:(NSCoder *)coder
{
    //int iXolrEncodingVersion = [coder decodeIntForKey:@"iXolrEncodingVersion"]; not used for now
    int iXolrIPadVersion = [coder decodeIntForKey:@"iXolrIPadVersion"];
    if (iXolrIPadVersion != [iXolrAppDelegate iPad] + 3)
        return NO;
    return YES;
}

- (UIViewController *)application:(UIApplication *)application viewControllerWithRestorationIdentifierPath:(NSArray *)identifierComponents coder:(NSCoder *)coder
{
    if (identifierComponents.count > 0) {
        NSUInteger lastItem = identifierComponents.count - 1;
        if ([identifierComponents[lastItem] isEqualToString: @"iXolrTopRoot"])
            return self.window.rootViewController;
        
        UIViewController *topVC = self.window.rootViewController;
        if ([topVC isKindOfClass:[UISplitViewController class]]) {
            topVC = ((UISplitViewController*)topVC).viewControllers[0];
        }
        UINavigationController *topNC = (UINavigationController*)topVC;
        if (![topNC isKindOfClass:[UINavigationController class]])
            return nil;

        if ([identifierComponents[lastItem] isEqualToString: @"iXolrTopNav"])
            return topNC;
        
        else if ([identifierComponents[lastItem] isEqualToString: @"conferenceList"]) {
            self.conferenceListViewController = (RootViewController*)topNC.topViewController;
            return self.conferenceListViewController;
        } else if ([identifierComponents[lastItem] isEqualToString: @"topicList"])
            return [self.conferenceListViewController createTopicViewController:[self.dataController conferenceWithName:self.currentConferenceName]];
        else if ([identifierComponents[lastItem] isEqualToString: @"DetailNav"])
            return self.detailViewController.navigationController;
        else if ([identifierComponents[lastItem] isEqualToString: @"detailView"])
            return self.detailViewController;
    }
    return nil;
}

- (void) setupRefreshTimer
{
    // Timer to generate a callback for auto-sync
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:self.settings.refreshSecs target:self selector:@selector(refreshTimerFired:) userInfo:nil repeats:YES];
    // Do one call quite quickly to get things rolling, if we haven't done it very recently
    if ([self.lastRefreshed timeIntervalSinceNow] < -MIN(self.settings.refreshSecs, 20.0))
        [self performSelector:@selector(refreshTimerFired:) withObject:nil afterDelay:2];
}

- (void) removeRefreshTimer
{
    [_refreshTimer invalidate];
    // crashes? [_refreshTimer release];
    _refreshTimer = nil;
}

// Take note of the current topic and conference name
- (void)currentTopicChanged:(NSNotification*)param
{
    Topic *topic = param.object;
    if (topic != nil) {
        self.currentTopicName = topic.name;
        self.currentConferenceName = topic.conference.name;
    }
}

// We have been told that the read count in a topic has changed, either for a single object
// or because someone has done something like 'mark all read'.
- (void)handleMessageReadCountChanged:(NSNotification*)param
{
    id<GenericMessage> message = [param userInfo][@"SingleMessage"];
    if (message != nil && self.settings.uploadReadStatus) {
        NSString *link = message.cixLink;
        if (message.isRead) {
            [_pendingMarkUnread removeObject:link];
            [_pendingMarkRead addObject:link];
        } else {
            [_pendingMarkRead removeObject:link];
            [_pendingMarkUnread addObject:link];
        }
    }
}

- (void)toggleFavouriteMessage:(id<GenericMessage>)message
{
    [self.dataController toggleFavouriteMessage:message];
    [self.dataController saveContext];  // Commit to database
    if (message != nil && self.settings.uploadStars) {
        NSString *link = message.cixLink;
        if (message.isFavourite) {
            [_pendingUnstar removeObject:link];
            [_pendingStar addObject:link];
        } else {
            [_pendingStar removeObject:link];
            [_pendingUnstar addObject:link];
        }
    }
}

// When the user turns on 'upload stars', put all current stars in 'pending' so they will get uploaded
- (void)uploadStarsTurnedOn
{
    for (CIXMessage *message in self.dataController.favouriteMessages)
        [_pendingStar addObject: message.cixLink];
}

#pragma mark - URL handling

- (void)handleNotFoundConf: (NSString*)confName
{
    //    [[iXolrAppDelegate singleton] requestTopicInfoForConfName:confName];
    NSString *str = [NSString stringWithFormat:@"You are not a member of conference \"%@\". Do you want to join?", confName];
    [self confirm:str title:@"Confirm Join" actionTitle:@"Join" ifConfirmed:^{
        [self joinConference:confName];
    }];
}

- (void) gotoConfName: (NSString*) confName topic: (NSString*) topicName msgnum: (NSString*) msgnum
{
    if ([confName length] == 0)
        confName = [iXolrAppDelegate singleton].currentConferenceName;
    Topic *topic = [self.dataController topicForConfName:confName topic:topicName];
    if (topic == nil)
        [self handleNotFoundConf:confName];
    else
        [self gotoTopic:topic msgnum:[msgnum integerValue] switchSubview:YES];
}

// Go to a CIX URL, which is of the form "cix:conf/topic:msgnum" or "cix:conf" or "cix:conf/topic" or "cix:msgnum"
- (void)gotoCIXurl:(NSURL *)url {
    NSString *path = [url resourceSpecifier];  // This gives us the path without "cix:" at the beginning
    NSArray *components = [path componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":/"]];
    if ([components count] == 3)
        [self gotoConfName:components[0] topic:components[1] msgnum:components[2]];
    else if ([components count] == 2)   // something like "cix:conf/topic"
        [self gotoConfName:components[0] topic:components[1] msgnum:nil];
    else if ([components count] == 1)
        if ([path rangeOfCharacterFromSet:[NSCharacterSet letterCharacterSet]].location == NSNotFound)   // No letters - must be a message number
            [self gotoTopic:nil msgnum:[path integerValue]];
        else  // Must be a conference name on its own
            [self gotoConfName:components[0] topic:nil msgnum:nil];
}

// Return the message for a CIX URL, which is of the form "cix:conf/topic:msgnum" only
- (CIXMessage *)messageForCIXurl:(NSString *)path {
    NSArray *components = [path componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":/"]];
    if ([components count] == 4) {  // 4 because first component is "cix"
        Topic *topic = [self.dataController topicForConfName:components[1] topic:components[2]];
        return [topic messageWithNumber:[components[3] integerValue]];
    }
    return nil;
}

// Central command point for other parts of the app to request that we move to a different point
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum
{
    [self.detailViewController gotoTopic:topic msgnum:msgnum];
}

- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum switchSubview:(BOOL)switchSubview
{
    if (switchSubview) {
        if (self.detailViewController == nil)
            [self.conferenceListViewController gotoTopic:topic msgnum:msgnum];
        else
            [self.conferenceListViewController switchSubViewToTopic:topic];
    }
    [self.detailViewController gotoTopic:topic msgnum:msgnum];
}

// Tell the display to go back to the topic we last viewed
- (void)gotoSavedLocation
{
    if (self.currentTopicName != nil && self.currentConferenceName != nil)
    {
        Conference *conf = [self.dataController conferenceWithName: self.currentConferenceName];
        Topic *topic = [conf topicWithName: self.currentTopicName];
        if (topic != nil) {
            [self.conferenceListViewController gotoConference:conf];
            [self gotoTopic:topic msgnum:0];
        }
    }
}

- (BOOL)application:(UIApplication *)application willFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    _pendingMarkRead   = [NSMutableSet setWithCapacity:100];
    _pendingMarkUnread = [NSMutableSet setWithCapacity:100];
    _pendingStar       = [NSMutableSet setWithCapacity: 10];
    _pendingUnstar     = [NSMutableSet setWithCapacity: 10];
    [self restoreState];
    
    return YES;
}

- (void)setupLogging
{
    _fileLogger = [[DDFileLogger alloc] init];
    _fileLogger.maximumFileSize = 1024*1024; // 1MB
    _fileLogger.logFileManager.maximumNumberOfLogFiles = 7;
    [DDLog addLogger:_fileLogger];
    //[DDLog addLogger:[DDASLLogger sharedInstance]];
    [DDLog addLogger:[DDTTYLogger sharedInstance]];
}

- (NSString*)recentLogs
{
    NSString* path = _fileLogger.currentLogFileInfo.filePath;
    NSError *error = nil;
    NSString* content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error];
    if (error != nil) {
        NSLog(@"Unable to log file %@: %@", path, error);
    }
    return content;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [self setupLogging];
    NSLog(@"didFinishLaunchingWithOptions: %@", launchOptions);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(currentTopicChanged:) name:@"currentTopicChanged" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageReadCountChanged:) name:@"messageReadCountChanged" object:nil];

    [application setMinimumBackgroundFetchInterval:UIApplicationBackgroundFetchIntervalMinimum];
    {
        UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
        center.delegate = self;
        [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionBadge) completionHandler: ^(BOOL granted, NSError *error){
        }];
    }
    
    if ([self.window.rootViewController isKindOfClass:[UISplitViewController class]])
        ((UISplitViewController*)self.window.rootViewController).delegate = self;

	_CIXhostReach = [Reachability reachabilityWithHostName: @"api.cixonline.com"];
	[_CIXhostReach startNotifier];
    _CIXRequestManager = [[CixRequestManager alloc] init];
    _queueForMessageParsing = [[NSOperationQueue alloc] init];
    _queueForMessageParsing.maxConcurrentOperationCount = 1;

    // Do rest of init on the operation queue so we don't take the hit in the init routine
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [self gotoSavedLocation];
    }];
    
    return YES;
}

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"applicationWillResignActive");
    [self removeRefreshTimer];
	[_CIXhostReach stopNotifier];
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"applicationDidEnterBackground");
    _notification = nil;
    _activationOp = nil;
    if (self.settings.outboxAlert && [self.dataController outboxMessageCountToUpload] > 0) {
        UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
        UNTimeIntervalNotificationTrigger* trigger = [UNTimeIntervalNotificationTrigger
                    triggerWithTimeInterval:60 * self.settings.outboxAlertMinutesDelay repeats:NO];
        content.body = @"iXolr has pending outbox messages";
        content.userInfo = @{@"link": @"outbox"};
        _notification = [UNNotificationRequest requestWithIdentifier:@"PendingOutbox" content:content trigger:trigger];
        [[UNUserNotificationCenter currentNotificationCenter] addNotificationRequest:_notification withCompletionHandler:nil];
    }
    [self saveState];
}

- (void) cancelOutboxNotification
{
    if (_notification != nil) {
        [[UNUserNotificationCenter currentNotificationCenter] removePendingNotificationRequestsWithIdentifiers:@[_notification.identifier]];
        _notification = nil;
    }
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"applicationWillEnterForeground");
    [self cancelOutboxNotification];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"applicationDidBecomeActive");
    if (_authStr == nil || consumer == nil)
        [self oauthInitAuthorization];
	[_CIXhostReach startNotifier];
    [[UNUserNotificationCenter currentNotificationCenter] getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings *settings) {
        self->_badgeAllowed = (settings.badgeSetting == UNNotificationSettingEnabled);
    }];
    [self setupRefreshTimer];
    [_activationOp start];
    _activationOp = nil;
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    [self saveState];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)performOnActivate: (void (^)(void)) block
{
    _activationOp = [NSBlockOperation blockOperationWithBlock: block];
}

- (BOOL)badgeAllowed
{
    return _badgeAllowed;
}

- (NSInteger) timeoutSecs
{
    if (backgroundFetchActive)
        return 25;  // must finish in under 30 secs
    else
        return self.settings.timeoutSecs;
}

- (void)application:(UIApplication *)application performFetchWithCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler
{
    NSLog(@"Background fetch initiated: autoSync = %d, username = %@, authStr ok = %d", self.settings.autoSync, self.CIXusername, _authStr != nil);
    backgroundFetchActive = YES;
    if (_authStr == nil || consumer == nil)
        [self oauthInitAuthorization];
    if (self.settings.autoSync && self.CIXusername != nil && _authStr != nil &&
        [self LoadNewMessagesWithErrorUI:NO completion:^(NSInteger msgCount) {
            if (msgCount > 0)
                completionHandler(UIBackgroundFetchResultNewData);
            else if (msgCount == 0)
                completionHandler(UIBackgroundFetchResultNoData);
            else
                completionHandler(UIBackgroundFetchResultFailed);
            self->backgroundFetchActive = NO;
        }])
        ;
    else {
        completionHandler(UIBackgroundFetchResultNoData);
        backgroundFetchActive = NO;
    }
    logMemUsage();
}

#import "mach/mach.h"

vm_size_t usedMemory(void) {
    struct task_basic_info info;
    mach_msg_type_number_t size = sizeof(info);
    kern_return_t kerr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
    return (kerr == KERN_SUCCESS) ? info.resident_size : 0;   // size in bytes
}

natural_t freeMemory(void) {
    mach_port_t           host_port = mach_host_self();
    mach_msg_type_number_t host_size = sizeof(vm_statistics_data_t) / sizeof(integer_t);
    vm_size_t              pagesize;
    vm_statistics_data_t   vm_stat;
    
    host_page_size(host_port, &pagesize);
    (void) host_statistics(host_port, HOST_VM_INFO, (host_info_t)&vm_stat, &host_size); 
    return vm_stat.free_count * (natural_t)pagesize;
}

void logMemUsage(void) {
    // compute memory usage and log if different by >= 100k
    static long prevMemUsage = 0;
    long curMemUsage = usedMemory();
    long memUsageDiff = curMemUsage - prevMemUsage;
    
    if (memUsageDiff > 100000 || memUsageDiff < -100000) {
        prevMemUsage = curMemUsage;
        NSLog(@"Memory used %7.0f (%+5.0f), free %7.0f kb", 
              curMemUsage/1000.0f, memUsageDiff/1000.0f, freeMemory()/1000.0f);
    }
}

- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
    NSLog(@"Memory used: %7.0f kb", usedMemory()/1000.0f);
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
}


#pragma mark - Data Controller

/**
 Returns the data controller for the application. If the controller doesn't already exist, it is created.
 */
- (DataController *)dataController
{
    if (_dataController != nil)
    {
        return _dataController;
    }
    
    // Create the data controller.
    _dataController = [[DataController alloc] init];
    return _dataController;
}

#pragma mark - OAuth

- (void)setupOAuth {
}

// Not really a username, but this is the slot we store it under in the keychain
static NSString* oauthUserName(void)
{
    return [iXolrAppDelegate iPad] ? @"cix_oauth_data" : @"cix_oauth_dataM";
}

NSString* const oauthServiceName = @"Callback_OAuth";

- (void)receiveAccessToken:(NSString*)dataString
{
	NSError *error = nil;	
    [SAMKeychain setPassword:dataString forService:oauthServiceName account:oauthUserName() error:&error];
    if (error) {
        NSLog(@"Error when storing token in keychain: %@", error);
        [self addBugReportMessage:error.description];
        @throw [NSException exceptionWithName:@"Exception" reason:@"The keychain, it hates us." userInfo:@{@"error":error}];
    }
    _authStr = dataString;
}

- (void)oauthFetchAuthStrFromKeychain {
	
	NSError	 *error = nil;
	_authStr = [SAMKeychain passwordForService:oauthServiceName account:oauthUserName() error:&error];
    if (_authStr != nil && !haveFixedKeychainAccessibility) {
        // Delete it and store it back so we know it has accessible-after-unlock access
        [SAMKeychain deletePasswordForService:oauthServiceName account:oauthUserName() error:&error];
        [SAMKeychain setPassword:_authStr forService:oauthServiceName account:oauthUserName() error:&error];
        NSLog(@"Re-stored oauth key to set accessibility");
        haveFixedKeychainAccessibility = YES;
    }
    if (error && error.code != errSecInteractionNotAllowed) {
        NSLog(@"Error when accessing keychain: %@", error);
        if (error.code != errSecItemNotFound)
            [self addBugReportMessage:error.description];
    }
}

- (void)oauthInitAuthorization {
    [self oauthFetchAuthStrFromKeychain];

    // These strings (the real ones) were generated on http://developer.cixonline.com
    if ([iXolrAppDelegate iPad])
        consumer = [[OAConsumer alloc] initWithKey:@"8117f8df0d5944a888dad3437e189c" secret:@"<redacted>"];
    else
        consumer = [[OAConsumer alloc] initWithKey:@"e388392fe9034809b72d5312f63380" secret:@"<redacted>"];
}

- (void)userNotificationCenter:(UNUserNotificationCenter *)center didReceiveNotificationResponse:(UNNotificationResponse *)response withCompletionHandler:(void (^)(void))completionHandler {
    NSLog(@"didReceiveNotificationResponse: %@", response);
    NSString *url = response.notification.request.content.userInfo[@"link"];
    if ([url hasPrefix:@"cix:"]) {
        CIXMessage *message = [self messageForCIXurl: url];
        if (message != nil)
            [self gotoTopic:message.topic msgnum:message.msgnum switchSubview:YES];
    } else if ([url isEqualToString:@"outbox"]) {
        [self.conferenceListViewController switchSubViewToOutbox];
    }
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url options:(NSDictionary<UIApplicationOpenURLOptionsKey,id> *)options {
    NSLog(@"handleOpenURL: %@", url);
    if ([[url scheme] isEqualToString:@"cix"]) {
        [self gotoCIXurl:url];
    } else if ([[url scheme] isEqualToString:@"x-com-ixolr-oauth"]) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"loginResponse" object:url];
    }
    
	return YES;
}

#pragma mark - Popup Activity Indicator

- (void)popupActivityIndicatorWithTitle: (NSString*)title
{
    [self popupActivityIndicatorWithTitle:title cancellable:YES];
}

- (void)popupActivityIndicatorWithTitle: (NSString*)title cancellable:(BOOL)cancellable
{
    NSLog(@"Showing activity indicator '%@'", title);
    if (_popup_hud != nil) {
        _popup_hud.labelText = title;
        [_popup_hud show:YES];
        return;
    }
    _popup_hud = [MBProgressHUD showHUDAddedTo:self.window animated:YES];
    _popup_hud.removeFromSuperViewOnHide = YES;
    _popup_hud.labelText = title;
    if (cancellable) {
        _popup_hud.detailsLabelText = @"Tap to cancel";
        [_popup_hud addGestureRecognizer:[[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(popupActivityIndicatorCancelled)]];
    }
}

- (void)popupActivityIndicatorProgress: (float)progress
{
    _popup_hud.mode = MBProgressHUDModeAnnularDeterminate;
    _popup_hud.progress = progress;
}

- (void)popdownActivityIndicator
{
    NSLog(@"Activity finished: '%@'", _popup_hud.labelText);
    [_popup_hud hide:YES];
    _popup_hud = nil;
}

// Handle cancel button on progress dialog
- (void)popupActivityIndicatorCancelled
{
    [_CIXRequestManager cancelAllCIXOperations];
}

- (void)opTitle:(NSString*)str buttonTitle:(NSString*)btnTitle start: (NSDate*)startDate mode:(UIDatePickerMode)mode ifConfirmedFrom:(UIViewController*) viewController Rect:(CGRect)rect goBlock:(void (^)(NSDate* date))goBlock
{
    if ([iXolrAppDelegate iPad]) {
        _popover = [[UIDatePickerPopover alloc] initWithDate:startDate mode:mode
             goBlock:goBlock goButtonTitle: btnTitle];
        [_popover presentPopoverFromRect:rect inView:viewController.view permittedArrowDirections:UIPopoverArrowDirectionLeft animated:YES];
    } else {
        UIAlertController *alert = [UIAlertController alertControllerWithDate:startDate title:str mode:mode
              goBlock:goBlock cancelButtonTitle:@"Cancel" destructiveButtonTitle:btnTitle];
        [viewController presentViewController:alert animated:YES completion:nil];
    }
}

- (void)purgeIfConfirmedFrom: (UIViewController*) viewController Rect:(CGRect)rect
{
    NSString *str = @"Do you want to erase threads older than this date from this device, to save space?";
    NSDate *startDate = [NSDate dateWithTimeIntervalSinceNow:-(60*60*24)*90/*days*/];
    [self opTitle:str buttonTitle:@"Erase Older" start:startDate mode:UIDatePickerModeDate ifConfirmedFrom:viewController Rect:rect goBlock:^(NSDate *date) {
        [[iXolrAppDelegate singleton].dataController purgeOlderThanDate: date];
    }];
}

#pragma mark - Error handling

- (void)addBugReportMessage: (NSString*)text
{
    Topic *bugTopic = [self.dataController findOrCreateConference:@"ixolr" Topic:@"bugs"];
    CIXMessage *message = [self.dataController createNewOutboxMessage:nil topic:bugTopic];
    NSString* versionLabel = [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"];
    message.text = [NSString stringWithFormat:@"Bug Report from %@\n%@", versionLabel, text];
    message.date = [NSDate date];   // get the time now
    message.isHeld = YES;
    [self.dataController addOutboxMessagesObject:message];
    [self.dataController saveContext];  // Commit to database
    [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:bugTopic];
}

- (void)displayErrorMessage: (NSString*)message title: (NSString*)title
{
    UIAlertController * alert = [UIAlertController popupWithTitle:title message:message];
    [alert action:@"OK" block:^{}];
    [self.window.rootViewController presentViewController:alert animated:YES completion:nil];
}

- (void)displayErrorTitle: (NSString*)title message:(NSString*)message {
    [self displayErrorMessage:message title:title];
}

- (void)alertNoMoreUnread
{
    [self displayErrorMessage:@"There are no more unread messages in your messagebase." title:@"No more unread"];
}

- (void)handleOperationError:(NSError*)error
{
    [_CIXRequestManager cancelAllCIXOperations];
    [self displayErrorMessage:[error localizedDescription] title:@"Communication Failure"];
}

- (void)confirm:(NSString*)message title: (NSString*)title actionTitle:(NSString *)actionTitle ifConfirmed:(void (^)(void))block
{
    [UIAlertController showWithTitle:title message:message actionTitle:actionTitle from:self.window.rootViewController ifConfirmed:^{
        block();
    }];
}

#pragma mark - CIX Requests

- (BOOL) requestCIXProfileWithCompletion:(void (^)(NSDictionary*))completionHandler {
    if (_authStr == nil || [_authStr isEqualToString:@""])
        return NO;  // not authorised
    CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        NSDictionary *results = [Parser parseJSONtoDictionary:data];
        if ([results isKindOfClass:[NSDictionary class]])
            completionHandler(results);
    };
    [userRequest makeGenericRequest:@"user/profile" consumer:consumer auth:_authStr];
    return YES;
}

- (void)findEmailAddressFor: (NSString*)otherCixUser completion:(void (^)(NSString*))completionHandler
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"user/%@/profile", otherCixUser];
    userRequest.continuation = ^(NSData* data) {
        NSDictionary *results = [Parser parseJSONtoDictionary:data];
        if ([results isKindOfClass:[NSDictionary class]])
        {
            NSString *emailAddress = results[@"Email"];
            completionHandler(emailAddress);
        }
    };
    [userRequest makeGenericRequest:request params:nil consumer:consumer auth:_authStr];
}

- (void)justPostedMessage:(CIXMessage*)message msgnum:(int)msgnum
{
    message.isOutboxMessage = NO;
    message.isInteresting = YES;
    message.msgnum = msgnum;
    message.author = [self CIXusername];
    message.date = [NSDate date];
    if (self.settings.myMessagesAutoread) {
        message.isRead = true;
        if (self.settings.uploadReadStatus)
            [self UploadReadStatus:true messages:[NSSet setWithObject:message.cixLink] withErrorUI:NO];
    }
    [self.dataController removeOutboxMessagesObject:message];
    [self.dataController addMyMessagesObject:message];
    [self.dataController saveContext];
    if ([self.dataController outboxMessageCountToUpload] == 0)
        [self cancelOutboxNotification];
}

- (void)sendOutboxMessageIfAvailable
{
    // If we have any more outbox messages pending, send one
    NSArray *outbox = [self.dataController outboxMessages];
    if ([outbox count] > 0)
    {
        if ([_CIXRequestManager hasQueuedOperationWithRequestStr:@"forums/post"])    // Check whether we have an existing post operation queued
            return;
        __block UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{   // Tell IOS we want this to finish
            NSLog(@"sendOutboxMessage expiration of BackgroundTask %lu", (unsigned long)taskIdentifier);
            [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
        }];
        
        CixRequestOperation *op = nil;
        for (CIXMessage *message in outbox) {
            if (message.isHeld)
                continue;
            op = [CixRequestOperation operationWithRequest:@"forums/post" params:nil consumer:consumer auth:_authStr successBlock:^(NSData* data){
                NSString *dataString = [data asUTF8String];
                NSLog(@"Post message result: %@", dataString);
                // normal result is a message number like "142", including the quotes
                if ([dataString length] < 2 || [dataString characterAtIndex:0] != '"' || [dataString characterAtIndex:1] < '0' || [dataString characterAtIndex:1] > '9') {
                    [self displayErrorMessage:dataString title:@"Unexpected result from Post"];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:nil];
                } else {
                    [self justPostedMessage:message msgnum:[[dataString substringFromIndex:1] intValue]];
                }
            }];
            op.startedBlock = ^(CixRequestOperation*op) {
                [[NSNotificationCenter defaultCenter] postNotificationName:@"postingMessage" object:message];
            };
            op.failureBlock = ^(NSError* error){
                // Run on main thread
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [self->_CIXRequestManager cancelAllCIXOperations];
                    if (error.code == 400 && [error.domain hasPrefix:@"\"RO topic"])
                        [self displayErrorMessage:[NSString stringWithFormat:@"While attempting to post a message, CIX sent back: %@",[error domain]] title:@"Read-only Topic"];
                    else
                        [self displayErrorMessage:[error localizedDescription] title:@"Communication Failure"];
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:error];
                }];
            };
            op.body = [DataController JSONfromMessage:message];
            [_CIXRequestManager addOperation: op];
        }
        [_CIXRequestManager addOperationWithBlock:^{
            [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
        }];
    }
}

- (void)UploadReadStatus:(BOOL)isRead messages:(NSSet*)messages withErrorUI:(BOOL)wantErrorUI  {
    if (messages.count == 0)
        return;
    NSLog(@"Uploading markread %d: %lu messages", isRead, (unsigned long) messages.count);
    NSString *request = [NSString stringWithFormat:@"forums/%s/markreadrange", isRead ? "true" : "false"];
    CixRequestOperation *op = [CixRequestOperation operationWithRequest:request params:nil consumer:consumer auth:_authStr successBlock: nil];
    op.body = [Parser JSONRangesfromMessageLinks:[messages allObjects]];
    op.successBlock = ^(NSData* data){
        [(isRead ? self->_pendingMarkRead : self->_pendingMarkUnread) minusSet: messages];
    };
    op.failureBlock = ^(NSError* error){
        if (wantErrorUI)
            [self handleOperationError:error];
    };
    [_CIXRequestManager addOperation: op];
}

- (void)UploadStarStatus:(BOOL)isAdd messages:(NSSet*)messageLinks withErrorUI:(BOOL)wantErrorUI  {
    if (messageLinks.count == 0)
        return;
    NSLog(@"Uploading star %d: %lu messages", isAdd, (unsigned long) messageLinks.count);
    for (NSString *link in messageLinks) {
        NSArray *components = [link componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":/"]];
        NSString *request = isAdd ? @"starred/add" : [NSString stringWithFormat:@"starred/%@/%@/%@/rem", components[1], components[2], components[3]];
        CixRequestOperation *op = [CixRequestOperation operationWithRequest:request params:nil consumer:consumer auth:_authStr successBlock: nil];
        if (isAdd)
            op.body = [Parser JSONfromMessageLink:link];
        op.successBlock = ^(NSData* data){
            [(isAdd ? self->_pendingStar : self->_pendingUnstar) removeObject:link];
        };
        CixRequestOperation *__weak weakOp = op;
        op.failureBlock = ^(NSError* error){
            if (error.code == 400) {  // API sends 400 if message was already starred
                weakOp.successBlock(nil);
            } else if (wantErrorUI) {
                NSString *msg = [NSString stringWithFormat:@"Failed star upload for %@: %@", link, error.description];
                error = [NSError errorWithDomain:msg code:error.code userInfo:error.userInfo];
                [self handleOperationError:error];
            }
        };
        [_CIXRequestManager addOperation: op];
    }
}

#define SYNC_COUNT 2000

- (NSString*)downloadSinceParams {
    static NSDateFormatter *formatter = nil;
    if (formatter == nil) {
        formatter = [[NSDateFormatter alloc] init];
        [formatter setTimeZone:[NSTimeZone timeZoneWithName:@"Europe/London"]]; // Send time in CIX' local timezone.
        [formatter setDateFormat:@"'&since='yyyy-MM-dd HH:mm:ss"];
    }
    NSString *since = @"";
    if (self.downloadSince != nil) {
        // Add one second because CIX interprets "since" as >=
        since= [formatter stringFromDate:[self.downloadSince dateByAddingTimeInterval:1]];
    }
    int start=0; // FIXME
    return [NSString stringWithFormat: @"start=%d&count=%d%@", start, SYNC_COUNT, since];
}

- (BOOL)LoadNewMessagesWithErrorUI:(BOOL)wantErrorUI completion:(void (^)(NSInteger))completionHandler{
    NSString *request =[NSString stringWithFormat:@"user/sync"];
    if ([_CIXRequestManager hasQueuedOperationWithRequestStr:request])    // Check whether we have an existing scratchpad operation queued
        return NO;
    
    [self saveState];
    __block UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{   // Tell IOS we want this to finish
        NSLog(@"LoadNewMessages expiration of BackgroundTask %lu", (unsigned long)taskIdentifier);
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    }];

    CixRequestOperation *op = [CixRequestOperation operationWithRequest:request params:[self downloadSinceParams] consumer:consumer auth:_authStr successBlock: nil];
    op.startedBlock = ^(CixRequestOperation* op){
        NSString *msg = [self.downloadSince asStringWith:@"Fetching since %@"];
        if (msg == nil)
            msg = @"Fetching messages";
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshStarted" object:msg];
    };
    op.successBlock = ^(NSData* data){
        NSString* CIXusername = [iXolrAppDelegate singleton].CIXusername;
        // Parse messages on main thread
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            NSDate *latest = nil;
            NSInteger count = [self.dataController updateMessagesFromJSONData:data user:CIXusername returnLatest:&latest];
            self.lastRefreshed = [NSDate date]; // current date
            if (latest == nil)
                latest = [NSDate dateWithTimeIntervalSinceNow:-30];
            if (self.downloadSince == nil || [self.downloadSince compare: latest] == NSOrderedAscending)
                self.downloadSince = latest;
            [self LoadedNewMessages: count withErrorUI:wantErrorUI task:taskIdentifier completion:completionHandler];
        }];
    };
    op.failureBlock = ^(NSError* error){
        if (wantErrorUI)
            [self handleOperationError:error];
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:error];
        completionHandler(-1);
    };
    op.postProgressNotifications = YES;
    [_CIXRequestManager addOperation: op];

    if (self.settings.uploadReadStatus) {
        [self UploadReadStatus:true messages:_pendingMarkRead withErrorUI:wantErrorUI];
        [self UploadReadStatus:false messages:_pendingMarkUnread withErrorUI:wantErrorUI];
    }
    if (self.settings.uploadStars) {
        // Upload our changes, positive and negative
        [self UploadStarStatus:true messages:_pendingStar withErrorUI:wantErrorUI];
        [self UploadStarStatus:false messages:_pendingUnstar withErrorUI:wantErrorUI];
    }
    
    return YES;
}

- (void)LoadedNewMessages: (NSInteger) count withErrorUI:(BOOL)wantErrorUI task: (UIBackgroundTaskIdentifier) taskIdentifier completion:(void (^)(NSInteger))completionHandler {
    [self.dataController finishedUpdatingMessages];
    [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    if (count > 100 && self.settings.autoSync && !backgroundFetchActive)  // If we got a lot of messages then there's probably more to come
        [self LoadNewMessagesWithErrorUI:wantErrorUI completion:completionHandler];
    else
        completionHandler(count);
}

- (void)doSyncWithUpload:(BOOL)upload withErrorUI:(BOOL)wantErrorUI {
    if (upload)
        [self sendOutboxMessageIfAvailable];
    iXolrAppDelegate *__weak weakSelf = self;
    // Indirect this so the upload-read-status can act on messages newly uploaded
    [_CIXRequestManager addOperationOnMainThread:^{
        [weakSelf LoadNewMessagesWithErrorUI:wantErrorUI completion:^(NSInteger unused){}];
    }];
}

- (IBAction)doSync:(id)sender {
    [self doSyncWithUpload:YES withErrorUI:YES];
}

- (void)cosySync:(BOOL)syncUnread
{
    [self popupActivityIndicatorWithTitle:@"Syncing Unread..."];
    if (syncUnread) {
        CixRequestOperation *op = [CixRequestOperation alloc];
        op = [op initWithRequest:@"user/cosypointers" params:@"maxresults=8000" consumer:consumer auth:_authStr successBlock:^(NSData* data){
            [self popupActivityIndicatorProgress:0.5f];
            [self.dataController updateUnreadFromJSONData:data underOperation:op];
        }];
        op.failureBlock = ^(NSError* error){ [self handleOperationError:error]; };
        [_CIXRequestManager addOperation: op];
    };
    [self addTidyOperationOnMainThread:^{
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:nil];
    }];
}

// Withdraw a message you posted
- (void)withdrawMessage:(CIXMessage*)message
{
    message.text = @"[Withdraw in progress...]";
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"forums/%@/%@/%d/withdraw", message.topic.conference.name, message.topic.name, message.msgnum];
    userRequest.continuation = ^(NSData* data) {
        NSString *dataString = [data asUTF8String];
        if ([dataString isEqualToString: @"\"Success\""])
            [self performSelector:@selector(downloadMessage:) withObject:message afterDelay:2];
        else
            [self displayErrorMessage:dataString title:@"Unexpected result from Withdraw"];
    };
    [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

// Re-download exactly one specified message from CIX - used by 'withdraw' after delay
- (void)downloadMessage:(CIXMessage*) message
{
    [self downloadMessages:@[@(message.msgnum)] conf:message.topic.conference.name topic:message.topic.name];
}

-(NSString*)printableStringFromMessageNumbers:(NSArray *)messages
{
    if (messages.count == 0)
        return @"(none)";
    NSMutableString *retvalue = [NSMutableString stringWithString:@""];
    NSArray *sortedMessages = [messages sortedArrayUsingSelector:@selector(compare:)];
    NSUInteger pos = 0;
    NSUInteger count = sortedMessages.count;
    do {
        int startNumber = [sortedMessages[pos] intValue];
        int lastNumber = startNumber;
        NSUInteger endOfRun = pos+1;
        for (; endOfRun < count; ++endOfRun)
            if ([sortedMessages[endOfRun] intValue] != lastNumber+1)
                break;
            else
                ++lastNumber;
        if (endOfRun-pos > 1)
            [retvalue appendString:[NSString stringWithFormat:@"%d-%d",startNumber,lastNumber]];
        else
            [retvalue appendString:[NSString stringWithFormat:@"%d",startNumber]];
        pos = endOfRun;
        if (pos < count)
            [retvalue appendString:@","];
    } while (pos < count);
    return retvalue;
}

- (void)addTidyOperationOnMainThread:(void (^)(void))action {
    iXolrAppDelegate *__weak weakSelf = self;
    [_CIXRequestManager addOperationOnMainThread:^{
        action();
        [[iXolrAppDelegate singleton] popdownActivityIndicator];
        [weakSelf.dataController saveContext];
    }];
}

// Back-fill a number of older messages by downloading from CIX.  Messages array contains NSNumbers with message ID numbers
- (void)downloadMessages:(NSArray *)messages conf:(NSString*)conf topic:(NSString*)topic;
{
    NSLog(@"Downloading messages %@", [self printableStringFromMessageNumbers:messages]);
    [self popupActivityIndicatorWithTitle: @"Downloading messages..."];
    NSUInteger total = [messages count];
    NSUInteger startPos = 0;
    do {
        NSRange subrange = {startPos,MIN(100, total-startPos)};
        CixRequestOperation *op = [CixRequestOperation operationWithRequest:@"forums/messagerange" params:nil consumer:consumer auth:_authStr successBlock:^(NSData* data){
            [[iXolrAppDelegate singleton] popupActivityIndicatorProgress:((float)(startPos+subrange.length)) / total];
            [self.dataController updateMessagesFromJSONData:data user:self.CIXusername returnLatest:nil];
        }];
        op.failureBlock = ^(NSError* error){ [self handleOperationError:error]; };
        op.body = [Parser JSONfromMessageNumbers:[messages subarrayWithRange:subrange] conf:conf topic:topic];
        [_CIXRequestManager addOperation: op];
        startPos += subrange.length;
    } while(startPos < total);

    iXolrAppDelegate *__weak weakSelf = self;
    [self addTidyOperationOnMainThread:^{
        [weakSelf.dataController finishedUpdatingMessages];
    }];
}

// Backfill an entire thread by downloading from CIX
- (void)backfillThread:(int)msgnum conf:(NSString*)conf topic:(NSString*)topic
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshStarted" object:@"Backfilling thread"];
    [self popupActivityIndicatorWithTitle: @"Backfilling thread"];
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        // We get back from downloadThread just the first line of each message, so we need to extract the ids and queue them up for full download
        if ([self.dataController requestMissingMessagesFromJSONData:data] == 0) {
            [self displayErrorMessage:@"The requested thread is not available at CIX" title:@"Back-fill failed"];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:nil];
        }
    };
    userRequest.failureBlock = ^(NSError* error){
        [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:nil];
    };
    NSString *request = [NSString stringWithFormat:@"forums/%@/%@/%d/thread", conf, topic, msgnum];
    [userRequest makeGenericRequest:request params:@"maxresults=8000" consumer:consumer auth:_authStr];
}

- (void)getMaxMsgNumForConf:(NSString*)confName topic:(NSString*)topicName then: (void (^)(NSInteger))continuation
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"forums/%@/topics", confName];
    userRequest.continuation = ^(NSData* data) {
        // NSString *dataString = [data asUTF8String];
        // NSLog(@"Result of user/topics: %@", dataString);
        NSInteger maxMsgNum = [self.dataController maxMessageNumForTopic2:topicName fromJSONData:data];
        NSLog(@"Max msgnum for conf %@ topic %@: %ld", confName, topicName, (long)maxMsgNum);
        continuation(maxMsgNum);
    };
    [userRequest makeGenericRequest:request params:nil consumer:consumer auth:_authStr];
}

- (void)refreshTopicList
{
    [self popupActivityIndicatorWithTitle:@"Syncing Topics..."];
    CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        NSArray *conferences = [self.dataController confListFromJSONData:data];
        int n = 1;
        float total = [conferences count];
        // Add an operation for each conference, to get the topics
        for (NSString *confName in conferences) {
            NSString *request = [NSString stringWithFormat:@"user/%@/topics", confName];
            CixRequestOperation *op = [CixRequestOperation operationWithRequest:request params:nil consumer:self->consumer auth:self->_authStr successBlock:^(NSData* data){
                [[iXolrAppDelegate singleton] popupActivityIndicatorProgress:n / total];
                [self.dataController updateTopicsInConference:confName fromJSONData:data];
            }];
            op.failureBlock = ^(NSError* error){ [self handleOperationError:error]; };
            [self->_CIXRequestManager addOperation: op];
            ++n;
        }
        [self addTidyOperationOnMainThread:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"topicInfoFinished" object:nil];
        }];
    };
    [userRequest makeGenericRequest:@"user/forums" params:@"maxresults=2000" consumer:consumer auth:_authStr];
}

- (void)joinConference:(NSString*)confName
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"forums/%@/join", confName];
    userRequest.continuation = ^(NSData* data) {
        NSString *dataString = [data asUTF8String];
        NSLog(@"Join conf result: %@", dataString);
        Conference *conf = [self.dataController conferenceWithName: confName];
        [conf setIsResigned:NO];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"changedConference" object:conf];
        // After joining a new conference, request info on the topics therein
        [self requestUserTopicInfoForConfName: confName];
    };
    [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

- (void)resignConference:(NSString*)confName
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"forums/%@/resign", confName];
    userRequest.continuation = ^(NSData* data) {
        NSString *dataString = [data asUTF8String];
        NSLog(@"Resign conf result: %@", dataString);
        // After resigning a conference, mark resigned in the database
        if ([dataString isEqualToString:@"\"Success\""]) {
            Conference *conf = [self.dataController conferenceWithName: confName];
            [conf setIsResigned:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"changedConference" object:conf];
        } else
            [self displayErrorMessage:dataString title:@"Resign failed"];
    };
    [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

- (void)resignConference:(NSString*)confName topic:(NSString*)topicName
{
    CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    NSString *request = [NSString stringWithFormat:@"forums/%@/%@/resigntopic", confName, topicName];
    userRequest.continuation = ^(NSData* data) {
        NSString *dataString = [data asUTF8String];
        NSLog(@"Resign topic result: %@", dataString);
        // After resigning a conference, mark resigned in the database
        if ([dataString isEqualToString:@"\"Success\""]) {
            Topic *topic = [self.dataController topicForConfName:confName topic:topicName];
            [topic setIsResigned:YES];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"changedConference" object:topic.conference];
        } else
            [self displayErrorMessage:dataString title:@"Resign failed"];
    };
    [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

- (void)requestDirectoryCategories
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData *data) {
        NSArray *categories = [self.dataController directoryCategoriesFromJSONData:data];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"directoryCategories" object:categories];
    };
    [userRequest makeGenericRequest:@"directory/categories" consumer:consumer auth:_authStr];
}

- (BOOL)requestDirectoryForCategory: (NSString*) categoryName
{
    // CIX has special work-around for '&' character
    categoryName = [categoryName stringByReplacingOccurrencesOfString:@"&" withString:@"+and+"];
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        NSArray *forums = [self.dataController directoryCategoryForumsFromJSONData:data];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"directoryCategoryForums" object:forums];
    };
    NSString *request = [NSString stringWithFormat:@"directory/%@/forums", categoryName];
    return [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

- (void)requestDirectorySearch: (NSString*)searchText
{
    CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        NSArray *forums = [self.dataController directoryCategoryForumsFromJSONData:data];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"directoryCategoryForums" object:forums];
    };
    [userRequest makeGenericPostRequest:@"directory/search" body:[Parser JSONfromSearchQuery:searchText] consumer:consumer auth:_authStr];
}

- (BOOL)requestUserTopicInfoForConfName: (NSString*)confName
{
    CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData* data) {
        [self.dataController updateTopicsInConference:confName fromJSONData:data];
    };
    userRequest.failureBlock = ^(NSError* error) {
        [[NSNotificationCenter defaultCenter] postNotificationName:@"topicInfoFinished" object:error];
    };
    NSString *request = [NSString stringWithFormat:@"user/%@/topics", confName];
    return [userRequest makeGenericRequest:request consumer:consumer auth:_authStr];
}

/* unused at present
- (void)fetchPrivateMessages
{
	CixRequest *userRequest = [CixRequest requestWithDelegate:self];
    userRequest.continuation = ^(NSData *data) {
        NSArray *messages = [self.dataController privateMessagesFromJSONData:data];
    };
    [userRequest makeGenericRequest:@"personalmessage/inbox" consumer:consumer auth:_authStr];
}
*/

#pragma mark - Request Callbacks

- (void)cixRequest:(CixRequest*)request finishedLoadingData:(NSData*)data
{
    if (request.continuation != nil)
        request.continuation(data);
}

- (void)cixRequest:(CixRequest*)request failedWithError:(NSError*)error
{
    [self popdownActivityIndicator];
    if (request.failureBlock != nil)
        request.failureBlock(error);
    [self displayErrorMessage:[error localizedDescription] title:@"Communication Failure"];
}

#pragma mark - AutoSync

- (void)refreshTimerFired:(NSTimer*)theTimer {
    if (_authStr == nil)
        [self oauthFetchAuthStrFromKeychain];
    if (self.settings.autoSync && self.CIXusername != nil && _authStr != nil && _CIXhostReach.currentReachabilityStatus != NotReachable) {
        [self doSyncWithUpload: self.settings.autoUpload withErrorUI:NO];
    }
    logMemUsage();
}

#pragma mark - Application's Documents directory

/**
 Returns the URL to the application's Documents directory.
 */
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

#pragma mark - Split view support

- (void)splitViewController:(UISplitViewController *)svc
    willChangeToDisplayMode:(UISplitViewControllerDisplayMode)displayMode {

    UINavigationController *nc = svc.viewControllers.lastObject;
    if (displayMode == UISplitViewControllerDisplayModePrimaryHidden) {
        nc.topViewController.navigationItem.leftBarButtonItem = svc.displayModeButtonItem;
    } else {
        nc.topViewController.navigationItem.leftBarButtonItem = nil;
    }
}
@end
