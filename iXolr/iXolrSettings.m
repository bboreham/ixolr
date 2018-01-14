//
//  iXolrSettings.m
//  iXolr
//
//  Created by Bryan Boreham on 12/11/2014.
//
//

#import "iXolrSettings.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"

@implementation iXolrSettings

@synthesize refreshSecs=_refreshSecs;
@synthesize squishRows=_squishRows;
@synthesize autoSync=_autoSync;
@synthesize autoUpload=_autoUpload;
@synthesize reflowText=_reflowText;
@synthesize inlineImages=_inlineImages;
@synthesize myMessagesVisible=_myMessagesVisible;
@synthesize threadsDefaultOpen=_threadsDefaultOpen;
@synthesize threadHeadersVisible=_threadHeadersVisible;
@synthesize animationsOn=_animationsOn;
@synthesize outboxAlert=_outboxAlert;
@synthesize outboxAlertMinutesDelay=_outboxAlertMinutesDelay;
@synthesize showMessageToolbar=_showMessageToolbar;
@synthesize messageFontSize=_messageFontSize;
@synthesize signature=_signature;
@synthesize markReadDays=_markReadDays;
@synthesize timeoutSecs=_timeoutSecs;
@synthesize useDynamicType=_useDynamicType;
@synthesize uploadReadStatus=_uploadReadStatus;
@synthesize uploadStars=_uploadStars;
@synthesize myMessagesAutoread=_myMessagesAutoread;

static void fetchIntegerValue(NSInteger *val, NSString* key, NSInteger defaultValue)
{
    if ([[NSUserDefaults standardUserDefaults] valueForKey:key] != nil)
        *val = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    else
        *val = defaultValue;
}

static void fetchFloatValue(float *val, NSString* key, float defaultValue)
{
    if ([[NSUserDefaults standardUserDefaults] valueForKey:key] != nil)
        *val = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    else
        *val = defaultValue;
}

static void fetchBoolValue(BOOL *val, NSString* key, BOOL defaultValue)
{
    if ([[NSUserDefaults standardUserDefaults] valueForKey:key] != nil)
        *val = [[NSUserDefaults standardUserDefaults] integerForKey:key];
    else
        *val = defaultValue;
}

- (void)restoreState
{
    fetchIntegerValue(&_refreshSecs, @"refreshSecs", 120);
    self.squishRows = [[NSUserDefaults standardUserDefaults] integerForKey:@"squishRows"];
    fetchBoolValue(&_autoSync, @"autoSync", YES);
    fetchBoolValue(&_autoUpload, @"autoUpload", NO);
    fetchBoolValue(&_reflowText, @"reflowText", [iXolrAppDelegate iPad] ? NO : YES);
    fetchBoolValue(&_inlineImages, @"inlineImages", YES);
    fetchBoolValue(&_myMessagesVisible, @"myMessagesVisible", YES);
    fetchBoolValue(&_threadsDefaultOpen, @"threadsDefaultOpen", NO);
    fetchBoolValue(&_threadHeadersVisible, @"threadHeadersVisible", YES);
    fetchBoolValue(&_outboxAlert, @"outboxAlert", NO);
    fetchBoolValue(&_animationsOn, @"animationsOn", YES);
    fetchFloatValue(&_outboxAlertMinutesDelay, @"outboxAlertMinutesDelay", 1);
    fetchFloatValue(&_messageFontSize, @"messageFontSize", [iXolrAppDelegate iPad] ? 17 : 15);
    fetchBoolValue(&_showMessageToolbar, @"showMessageToolbar", [iXolrAppDelegate iPad] ? NO : YES);
    self.signature = [[NSUserDefaults standardUserDefaults] stringForKey:@"signature"];
    fetchIntegerValue(&_markReadDays, @"markReadDays", 3);
    fetchIntegerValue(&_timeoutSecs, @"timeoutSecs", 300);
    fetchBoolValue(&_useDynamicType, IXSettingUseDynamicType, YES);
    fetchBoolValue(&_uploadReadStatus, @"uploadReadStatus", YES);
    fetchBoolValue(&_uploadStars, @"uploadStars", NO);
    fetchBoolValue(&_myMessagesAutoread, @"myMessagesAutoread", NO);
    //useBetaAPI = YES;
}

- (void)saveState
{
    [[NSUserDefaults standardUserDefaults] setInteger:self.refreshSecs forKey:@"refreshSecs"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.squishRows forKey:@"squishRows"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.autoSync forKey:@"autoSync"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.autoUpload forKey:@"autoUpload"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.reflowText forKey:@"reflowText"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.inlineImages forKey:@"inlineImages"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.myMessagesVisible forKey:@"myMessagesVisible"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.threadsDefaultOpen forKey:@"threadsDefaultOpen"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.threadHeadersVisible forKey:@"threadHeadersVisible"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.outboxAlert forKey:@"outboxAlert"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.outboxAlertMinutesDelay forKey:@"outboxAlertMinutesDelay"];
    [[NSUserDefaults standardUserDefaults] setFloat:self.messageFontSize forKey:@"messageFontSize"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.showMessageToolbar forKey:@"showMessageToolbar"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.animationsOn forKey:@"animationsOn"];
    [[NSUserDefaults standardUserDefaults] setObject:self.signature forKey:@"signature"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.markReadDays forKey:@"markReadDays"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.timeoutSecs forKey:@"timeoutSecs"];
    [[NSUserDefaults standardUserDefaults] setInteger:_useDynamicType forKey:IXSettingUseDynamicType];
    [[NSUserDefaults standardUserDefaults] setInteger:self.uploadReadStatus forKey:@"uploadReadStatus"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.uploadStars forKey:@"uploadStars"];
    [[NSUserDefaults standardUserDefaults] setInteger:self.myMessagesAutoread forKey:@"myMessagesAutoread"];
}

- (void)setMessageFontSize:(float)messageFontSize
{
    _messageFontSize = messageFontSize;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSettingsChanged" object:nil];
}

- (void)setReflowText:(BOOL)reflowText
{
    _reflowText = reflowText;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSettingsChanged" object:nil];
}

- (void)setInlineImages:(BOOL)inlineImages
{
    _inlineImages = inlineImages;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSettingsChanged" object:nil];
}

- (void)setMyMessagesVisible:(BOOL)myMessagesVisible
{
    [[iXolrAppDelegate singleton].dataController willChangeValueForKey:@"myMessages"];
    _myMessagesVisible = myMessagesVisible;
    [[iXolrAppDelegate singleton].dataController didChangeValueForKey:@"myMessages"];
}

- (void)setThreadHeadersVisible:(BOOL)threadHeadersVisible
{
    _threadHeadersVisible = threadHeadersVisible;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"threadSettingsChanged" object:nil];
}

- (void)setThreadsDefaultOpen:(BOOL)threadsDefaultOpen
{
    _threadsDefaultOpen = threadsDefaultOpen;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"threadSettingsChanged" object:nil];
}

- (void)setUseDynamicType:(BOOL)useDynamicType
{
    [[iXolrAppDelegate singleton].dataController willChangeValueForKey:IXSettingUseDynamicType];
    _useDynamicType = useDynamicType;
    [[iXolrAppDelegate singleton].dataController didChangeValueForKey:IXSettingUseDynamicType];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageSettingsChanged" object:nil];
}

- (void)setUploadStars:(BOOL)uploadStars
{
    if (!_uploadStars && uploadStars)
        [[iXolrAppDelegate singleton] uploadStarsTurnedOn];
    _uploadStars = uploadStars;
}

- (void)setMyMessagesAutoread:(BOOL)myMessagesAutoread {
    _myMessagesAutoread = myMessagesAutoread;
}
@end
