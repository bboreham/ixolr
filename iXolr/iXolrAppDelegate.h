//
//  iXolrAppDelegate.h
//  iXolr
//
//  Created by Bryan Boreham on 29/04/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CixRequest.h"
#import "iXolrSettings.h"

@class RootViewController;
@class DetailViewController;
@class DataController;
@class Reachability;
@class Topic;
@class CIXMessage;
@protocol GenericMessage;

@interface iXolrAppDelegate : NSObject <UIApplicationDelegate,UIAlertViewDelegate,CixRequestDelegate,UISplitViewControllerDelegate> 

// Return the singleton delegate for the current application
+ (iXolrAppDelegate*) singleton;
+ (iXolrSettings*) settings;    // Singleton's settings, to reduce typing
+ (BOOL) iPad;  // Are we running on an iPad?

@property (nonatomic, strong) IBOutlet UIWindow *window;

- (void)saveState;
- (void)addBugReportMessage: (NSString*)text;
- (void)receiveAccessToken:(NSString*)dataString;
- (NSURL *)applicationDocumentsDirectory;
- (BOOL) requestCIXProfileWithCompletion:(void (^)(NSDictionary*))completionHandler;
- (IBAction)doSync:(id)sender;
- (void)purgeIfConfirmedFrom: (UIViewController*) viewController Rect:(CGRect)rect;
- (void)opTitle:(NSString*)str buttonTitle:(NSString*)btnTitle start: (NSDate*)startDate mode:(UIDatePickerMode)mode ifConfirmedFrom:(UIViewController*) viewController Rect:(CGRect)rect goBlock:(void (^)(NSDate* date))goBlock;
- (void)withdrawMessage:(CIXMessage*)message;
- (void)toggleFavouriteMessage:(id<GenericMessage>)message;
- (void)downloadMessages:(NSArray *)messages conf:(NSString*)conf topic:(NSString*)topic;
- (void)getMaxMsgNumForConf:(NSString*)confName topic:(NSString*)topicName then: (void (^)(NSInteger))continuation;
- (void)backfillThread:(int)msgnum conf:(NSString*)conf topic:(NSString*)topic;
- (void)refreshTopicList ;
- (void)cosySync:(BOOL)syncUnread;
- (void)requestDirectoryCategories;
- (BOOL)requestDirectoryForCategory: (NSString*) categoryName;
- (void)requestDirectorySearch: (NSString*)searchText;
- (void)joinConference:(NSString*)confName;
- (void)resignConference:(NSString*)confName;
- (void)resignConference:(NSString*)confName topic:(NSString*)topicName;
- (void)findEmailAddressFor: (NSString*)otherCixUser completion:(void (^)(NSString*))completionHandler;
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum;
- (void)gotoTopic:(Topic*)topic msgnum:(NSInteger)msgnum switchSubview:(BOOL)switchSubview;
- (CIXMessage *)messageForCIXurl:(NSString *)path;
- (void)displayErrorMessage: (NSString*)message title: (NSString*)title;
- (void)displayErrorTitle: (NSString*)title message:(NSString*)message;
- (void)alertNoMoreUnread;
- (void)confirm:(NSString*)message title: (NSString*)title actionTitle:(NSString *)actionTitle ifConfirmed:(void (^)(void))block;
- (void)popupActivityIndicatorWithTitle: (NSString*)title;
- (void)popupActivityIndicatorWithTitle: (NSString*)title cancellable:(BOOL)cancellable;
- (void)popupActivityIndicatorProgress: (float)progress;
- (void)popdownActivityIndicator;
- (void)uploadStarsTurnedOn;
- (NSString*)recentLogs;

@property (nonatomic, strong) RootViewController *conferenceListViewController;
@property (nonatomic, strong) DetailViewController *detailViewController;

@property (nonatomic, strong) DataController *dataController;
@property(nonatomic,strong) OAConsumer *consumer;
@property (nonatomic, strong) iXolrSettings *settings;
@property(nonatomic,strong) NSString *CIXusername;
@property (nonatomic, strong) NSDate* lastRefreshed;
@property (nonatomic, strong) NSDate* downloadSince;
@property (nonatomic) float threadWindowSize;
@property (nonatomic,strong) NSString *currentConferenceName;
@property (nonatomic,strong) NSString *currentTopicName;
@property (nonatomic, readonly) BOOL badgeAllowed;

@end

extern NSString * const IXSettingUseDynamicType;
