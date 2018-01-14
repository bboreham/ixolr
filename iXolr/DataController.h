/*
     File: DataController.h
 Abstract: A controller class responsible for managing the application's data.
 
 */

@class NSManagedObjectContext;
@class NSManagedObjectModel;
@class NSPersistentStoreCoordinator;
@class CIXMessage;
@class Conference;
@class Topic;
@class Parser;
@protocol GenericMessage;

@interface DataQueryHelper : NSObject
- (void)saveContext;
- (Topic*)findOrCreateConference:(NSString*)name Topic: (NSString*)topicName;
- (Conference*)conferenceWithName:(NSString*)name;
- (Topic*) topicForConfName: (NSString*) confName topic: (NSString*) topicName;
- (CIXMessage*)createNewMessage;
- (NSArray*)messagesCommentingOn:(NSInteger)msgnum inTopic:(Topic*)topic;
- (CIXMessage*)messageWithNumber:(NSInteger)msgnum inTopic:(Topic*)topic;
@end

@interface DataController : DataQueryHelper

@property (nonatomic, strong, readonly) NSManagedObjectContext *managedObjectContext;
@property (nonatomic, strong, readonly) NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;

- (NSInteger)updateMessagesFromJSONData: (NSData*)jsondata user: (NSString*) CIXusername returnLatest:(NSDate**)latest;
- (void)updateUnreadFromJSONData: (NSData*)jsondata underOperation: (NSOperation*)op;
- (void)updateTopicsInConference: (NSString*)confName fromJSONData: (NSData*)jsondata;
- (NSInteger) maxMessageNumForTopic:(NSString*)topicName fromJSONData: (NSData*)jsondata;
- (NSInteger) maxMessageNumForTopic2:(NSString*)topicName fromJSONData: (NSData*)jsondata;
- (NSArray*)confListFromJSONData: (NSData*)jsondata ;
- (void)finishedUpdatingMessages;
- (NSUInteger)requestMissingMessagesFromJSONData: (NSData*)jsondata;
- (NSArray*)directoryCategoriesFromJSONData: (NSData*)jsondata;
- (NSArray*)directoryCategoryForumsFromJSONData: (NSData*)jsondata ;
- (NSArray*)privateMessagesFromJSONData: (NSData*)jsondata;
- (NSArray*)starredMessagesFromJSONData: (NSData*)jsondata;
+ (NSData*)JSONfromMessage:(CIXMessage*)message;

- (NSInteger) countOfUnread;
- (NSInteger) countOfInteresting;
- (void)deleteConference:(Conference*)conf;
- (NSArray *)fetchAllConferences;
- (void) fetchAllTopicCounts;
- (NSInteger) countMessagesInTopic:(Topic*)topic;
- (NSInteger) countUnReadMessagesInTopic:(Topic*)topic;
- (NSInteger) countInterestingMessagesInTopic:(Topic*)topic;
- (NSArray*)messagesInTopic:(Topic*)topic;
- (NSArray*)messagesSortedByMsgnumDesc:(Topic*)topic;
- (NSArray*)messagesSortedForThreadingInTopic:(Topic*)topic;
- (Topic*)nextTopicWithUnreadAfter:(Topic*)topic;
- (Topic*)nextInterestingTopicAfter:(Topic*)topic;
- (void)alertNoMoreUnread;
- (CIXMessage*)createNewOutboxMessage:(CIXMessage*)origMessage topic:(Topic*)topic;
- (void)removeOutboxMessagesObject:(CIXMessage*)message;
- (void)addMyMessagesObject:(CIXMessage*)message;
- (void)deleteMessage:(CIXMessage*)message;
- (void) deleteMessagesInArray: (NSArray*)array fromPos: (NSUInteger)start toPos: (NSUInteger)end;

- (void)addOutboxMessagesObject:(CIXMessage*)message;
- (NSArray*)outboxMessages;
- (NSUInteger)outboxMessageCount;
- (NSUInteger)outboxMessageCountToUpload;
- (NSArray*)favouriteMessages;
- (NSUInteger)favouriteMessageCount;
- (void)toggleFavouriteMessage:(id<GenericMessage>)message;
- (NSArray*)myMessages;
- (NSUInteger)myMessageCount;

- (void)markReadOlderThanDate:(NSDate*)date;
- (void)purgeOlderThanDate:(NSDate*)date;
- (void)VacuumStore;

@end

@interface CIXCategory : NSObject {
}
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSArray* subCategories;
@end

@interface CIXSubCategory : NSObject {
}
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSArray* forums;
@end

/*@interface CIXConfDescription : NSObject {
}
@property (nonatomic, retain) NSString* name;
@property (nonatomic, retain) NSString* title;
@property (nonatomic, retain) NSString* type;
@property (nonatomic) NSInteger recent;
@end
*/
