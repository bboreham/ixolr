//
//  Topic.h
//  iXolr
//
//  Created by Bryan Boreham on 05/07/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Conference, CIXMessage;
@protocol GenericMessage;

enum {
    TopicFlagsNone=0,
    TopicFlagsReadOnly=1,
    TopicFlagsMute=2,
    TopicFlagsResigned=4,
};

@interface Topic : NSManagedObject

@property (nonatomic, strong) NSString * name;
@property (nonatomic, strong) NSString * topicDescr;
@property (nonatomic, strong) Conference * conference;
@property (nonatomic) int32_t flags;

@property (nonatomic, readonly) NSInteger messageCount;
@property (nonatomic, readonly) NSInteger messagesUnreadCount;
@property (nonatomic, readonly) NSInteger interestingMessagesCount;
@property (nonatomic) BOOL isReadOnly;
@property (nonatomic) BOOL isMute;
@property (nonatomic) BOOL isResigned;
@property (weak, nonatomic, readonly) NSString * fullName;

- (CIXMessage*) messageWithNumber: (NSInteger)num;
- (void) markAllMessagesRead;
- (void) markAllMessagesReadOlderThanDate:(NSDate*)compareDate;
- (void) purgeThreadsOlderThanDate:(NSDate*)compareDate;
- (void) setMessagesUnreadUpToMsgnum:(NSInteger)msgnum;
- (void) messageReadStatusChanged: (id<GenericMessage>)message;
- (void) messageMultipleReadStatusChanged;
- (void) setCachedMessageCount: (NSInteger)count;   // Only for use by DataController
- (void) setCachedUnreadCount: (NSInteger)count;    // Only for use by DataController
- (void) setCachedInterestingCount: (NSInteger)count;    // Only for use by DataController
- (NSArray *)messagesThreaded;
- (void)downloadMissingMessages: (NSInteger)max;

- (void)notifyNew: (NSInteger)newMessages unread: (NSInteger)unread interesting: (NSInteger)interesting;
- (void)notifyMessageRemoved:(CIXMessage *)value;
@end
