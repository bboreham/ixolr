//
//  Conference.h
//  iXolr
//
//  Created by Bryan Boreham on 23/12/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Topic;

@interface Conference : NSManagedObject

@property (nonatomic, strong) NSString * name;
@property (nonatomic) int32_t flags;
@property (nonatomic, strong) NSSet * topics;
@property (nonatomic, strong) NSSet *moderators;
@property (nonatomic) int32_t ordering;
@end

@interface Conference (CoreDataGeneratedAccessors)
- (void)addTopicsObject:(Topic *)value;
- (void)removeTopicsObject:(Topic *)value;
- (void)addTopics:(NSSet *)values;
- (void)removeTopics:(NSSet *)values;

- (void)addModeratorsObject:(NSManagedObject *)value;
- (void)removeModeratorsObject:(NSManagedObject *)value;
- (void)addModerators:(NSSet *)values;
- (void)removeModerators:(NSSet *)values;

- (NSArray*)topicsSortedArray;
- (Topic*)topicWithName:(NSString*)name;
- (Topic*)firstTopicWithInterestingMessagesAfter: (Topic*)start;
- (Topic*)firstTopicWithUnreadMessagesAfter: (Topic*)start;
- (NSInteger) messageCount;
- (NSInteger) messagesUnreadCount;
- (NSInteger) interestingMessagesCount;
- (void) markAllMessagesRead;
- (void) setIsResigned:(BOOL)isResigned;
@property (nonatomic) BOOL isResigned;

@end

