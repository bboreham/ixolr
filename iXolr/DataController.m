/*
     File: DataController.m
 Abstract: A simple controller class responsible for managing the application's data.
 
 */

#import "DataController.h"
#import "Message.h"
#import "Conference.h"
#import "Topic.h"
#import "iXolrAppDelegate.h"
#import "TableViewUtilities.h"
#import "Parser.h"
#import <sqlite3.h>
#import <CoreData/CoreData.h>

@interface NSExpressionDescription (Convenience)
+(NSExpressionDescription*)allocWithFunction: (NSString*)function forKeyPath: (NSString*)keyPath withName: (NSString*)name;
@end

@implementation NSExpressionDescription (Convenience)
+(NSExpressionDescription*)allocWithFunction: (NSString*)function forKeyPath: (NSString*)keyPath withName: (NSString*)name
{
    NSExpression *keyPathExpression = [NSExpression expressionForKeyPath:keyPath];
    
    NSExpression *expression = [NSExpression expressionForFunction:function arguments:@[keyPathExpression]];
    
    NSExpressionDescription *expressionDescription = [[NSExpressionDescription alloc] init];
    [expressionDescription setName:name];
    [expressionDescription setExpression:expression];
    [expressionDescription setExpressionResultType:NSInteger32AttributeType]; 
    
    return expressionDescription;
}
@end

typedef void (^CancellableBlock)(NSOperation*);   // Used to define a block which can check to see if it's been cancelled

@interface CancellableBlockOperation : NSOperation {
    @private
    CancellableBlock _block;
}
+ (id) operationWithBlock: (CancellableBlock)block;
@end

@implementation CancellableBlockOperation

+ (id) operationWithBlock: (CancellableBlock)block
{
    CancellableBlockOperation *op = [[CancellableBlockOperation alloc] init];
    op->_block = [block copy];
    return op;
}


- (void)main {
    if (![self isCancelled])
        _block(self);
}

- (void) iXolrCancel {
    [self cancel];
}
@end

#pragma mark - DataQueryHelper
@implementation DataQueryHelper
{
    @protected
    NSManagedObjectContext *__managedObjectContext;
}


- (void)initializeWithPersistentStoreCoordinator: (NSPersistentStoreCoordinator *)coordinator
{
    __managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [__managedObjectContext setPersistentStoreCoordinator:coordinator];
    [__managedObjectContext setUndoManager:nil];
}

#pragma mark - Core Data stack

- (NSFetchRequest*)allocFetchRequestForEntity: (NSString*)entityName
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:__managedObjectContext];
    [fetchRequest setEntity:entity];
    return fetchRequest;
}

- (NSArray*)fetchForEntity:(NSString*)entityName predicate:(NSPredicate*)predicate orderBy:(NSString*)orderByFieldName ascending:(BOOL)ascending
{
    NSFetchRequest *fetchRequest = [self allocFetchRequestForEntity:entityName];
    [fetchRequest setPredicate:predicate];
    if (orderByFieldName != nil)
        [fetchRequest setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:orderByFieldName ascending:ascending]]];
    NSError *error = nil;
    NSArray *fetchedItems = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedItems == nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    return fetchedItems;
}

- (NSArray*)fetchForEntity:(NSString*)entityName predicate:(NSPredicate*)predicate
{
    return [self fetchForEntity:entityName predicate:predicate orderBy:nil ascending:NO];
}

- (NSInteger) executeSimpleFunction: (NSString*)function onEntity: (NSString*)entity forKeyPath: (NSString*)keyPath withPredicate: (NSPredicate*)predicate
{
    [self saveContext]; // Need to save any pending changes, otherwise the result of the query will be wrong.
    NSInteger returnValue = 0;
    NSFetchRequest *fetchRequest = [self allocFetchRequestForEntity:entity];
    [fetchRequest setResultType:NSDictionaryResultType];
    
    NSExpressionDescription *expressionDescription = [NSExpressionDescription allocWithFunction: function forKeyPath: keyPath withName: @"XXX"];
    
    [fetchRequest setPropertiesToFetch:@[expressionDescription]];
    [fetchRequest setPredicate:predicate];
    
    NSError *error = nil;
    NSArray * results = [__managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (results == nil || error != nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    else {
        if ([results count] > 0) {
            NSNumber *val = [results[0] valueForKey:[expressionDescription name]];
            returnValue = [val integerValue];
        }
    }
    
    return returnValue;
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = __managedObjectContext;
    if (managedObjectContext != nil)
    {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error])
        {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (void)saveContextAndHandleError
{
    [self saveContext];
}

// Returns autoreleased message object
- (CIXMessage*)createNewMessage
{
    CIXMessage *message = (CIXMessage*)[NSEntityDescription insertNewObjectForEntityForName:@"Message" inManagedObjectContext:__managedObjectContext];
    return message;
}

- (Conference*)conferenceWithName:(NSString*)name
{
    Conference *retval = nil;
    NSArray *fetchedItems = [self fetchForEntity:@"Conference" predicate:[NSPredicate predicateWithFormat:@"name=%@", name]];
    if ([fetchedItems count] > 0)
        retval = fetchedItems[0];
    return retval;
}

// Find a conference and topic; if topicName is nil then return any topic
- (Topic*) topicForConfName: (NSString*) confName topic: (NSString*) topicName
{
    Topic *topic = nil;
    if ([confName length] == 0)
        confName = [iXolrAppDelegate singleton].currentConferenceName;
    Conference *conf = [self conferenceWithName:confName];
    if (conf != nil)
        if (topicName == nil)  // Topic not specified: any one will do
            topic = [[conf topics] anyObject];
        else
            // Use findOrCreate so that, if we don't have a local record of this topic, it gets created
            topic = [self findOrCreateConference: confName Topic: topicName];
    return topic;
}

// Called during parsing, when we move from one topic to another.  Looks up the names in the database,
// and creates new objects if they don't currently exist.
- (Topic*)findOrCreateConference:(NSString*)name Topic: (NSString*)topicName
{
    Conference *conf = [self conferenceWithName: name];
    if (conf == nil)
    {
        NSLog(@"Creating conference %@", name);
        conf = (Conference*)[NSEntityDescription insertNewObjectForEntityForName:@"Conference" inManagedObjectContext:__managedObjectContext];
        conf.name = name;
    }
    if (conf.topics.count == 0)
        NSLog(@"Conference with zero topics: %@", name);
    Topic *topic = [conf topicWithName: topicName];
    if (topic == nil)
    {
        NSLog(@"Creating topic %@/%@", name, topicName);
        // Add this new topic to the conference
        topic = (Topic*)[NSEntityDescription insertNewObjectForEntityForName:@"Topic" inManagedObjectContext:__managedObjectContext];
        topic.name = topicName;
        [conf addTopicsObject:topic];
        [self saveContextAndHandleError];
    }
    return topic;
}

- (NSArray*)messagesCommentingOn:(NSInteger)msgnum inTopic:(Topic*)topic
{
    return [self fetchForEntity:@"Message" predicate:[NSPredicate predicateWithFormat:@"commentTo=%d and topic=%@", msgnum, topic]];
}

- (CIXMessage*)messageWithNumber:(NSInteger)msgnum inTopic:(Topic*)topic
{
    CIXMessage *retval = nil;
    NSArray *fetchedItems = [self fetchForEntity:@"Message" predicate:[NSPredicate predicateWithFormat:@"msgnum=%d and topic=%@", msgnum, topic]];
    if ([fetchedItems count] > 0)
        retval = fetchedItems[0];
    return retval;
}

@end

#pragma mark - DataController

//------------------------------------------------
// Main DataController implementation starts here
@implementation DataController
{
    NSMutableArray *_outbox;
    NSMutableArray *_favourites;
    NSMutableArray *_myMessages;
    Parser *_parser;
    BOOL _firstTimeInitialized, _firstTimeInitPending;
    NSArray* _conferences;
    NSInteger _totalUnread, _totalInteresting;
}

@synthesize managedObjectModel=__managedObjectModel;

@synthesize persistentStoreCoordinator=__persistentStoreCoordinator;



- (id)init {
    if ((self = [super init])) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleManagedObjectSave:) name:NSManagedObjectContextDidSaveNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleChangedMessagesInTopic:) name:@"changedMessagesInTopic" object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleMessageReadCountChanged:) name:@"messageReadCountChanged" object:nil];
    }
    return self;
}


- (void)updateContext:(NSNotification *)notification
{
    //NSLog(@"Calling mergeChangesFromContextDidSaveNotification");
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    //NSLog(@"Finished mergeChangesFromContextDidSaveNotification");
}

// Called from NSManagedObjectContextDidSaveNotification on the thread where the save happens
- (void)handleManagedObjectSave:(NSNotification*)notification
{
    if ([notification object] == __managedObjectContext) {
        // main context save, no need to perform the merge
        return;
    }
    [self performSelectorOnMainThread:@selector(updateContext:) withObject:notification waitUntilDone:YES];
}

#pragma mark - Totals

- (NSInteger) countOfUnread { return _totalUnread; }
- (void) setCountOfUnread: (NSInteger)total { _totalUnread = total; }
- (NSInteger) countOfInteresting { return _totalInteresting; }
- (void) setCountOfInteresting: (NSInteger)total { _totalInteresting = total; }

- (void)recomputeTotalUnread
{
    NSInteger totalUnread = 0;
    NSInteger totalInteresting = 0;
    for (Conference *conf in [self fetchAllConferences]) {
        totalUnread += conf.messagesUnreadCount;
        totalInteresting += conf.interestingMessagesCount;
    }
    self.countOfUnread = totalUnread;
    self.countOfInteresting = totalInteresting;
}

// Notification has arrived of new messages in one topic
- (void)handleChangedMessagesInTopic:(NSNotification*)param
{
    [self recomputeTotalUnread];
}

// Notification has arrived that the read-count of a topic has changed.
- (void)handleMessageReadCountChanged:(NSNotification*)param
{
    Topic *topic = [param object];
    NSNumber *prevUnread = [param userInfo][@"PreviousUnreadCount"];
    NSNumber *prevInteresting = [param userInfo][@"PreviousInterestingCount"];
    if (prevUnread != nil) {
        self.countOfUnread += (topic.messagesUnreadCount - [prevUnread integerValue]);
        self.countOfInteresting += (topic.interestingMessagesCount - [prevInteresting integerValue]);
    } else
        [self recomputeTotalUnread];
}

#pragma mark - Outbox

- (void)asyncInitialize
{
    if (_firstTimeInitPending)
        return;
    _firstTimeInitPending = YES;
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSLog(@"Starting async initialize");
        // Put in the predicates for three queries at once, so we can minimize I/O to the database, but we have to split the objects back out again ourselves.
        NSMutableArray *new_outbox = [NSMutableArray arrayWithCapacity:20];
        NSMutableArray *new_favourites = [NSMutableArray arrayWithCapacity:20];
        NSMutableArray *new_myMessages = [NSMutableArray arrayWithCapacity:100];
        NSString *myName = [iXolrAppDelegate singleton].CIXusername;
        NSPredicate *mp = [NSPredicate predicateWithFormat:@"(msgnum>=999999) || ((flags&8) != 0) || (author=%@ and date>%@)", myName, [NSDate dateWithTimeIntervalSinceNow:-90*3600*24]];
        NSArray *msgs = [self fetchForEntity:@"Message" predicate:mp orderBy:@"date" ascending:NO];
        for (CIXMessage *message in msgs) {
            if (message.isOutboxMessage)
                [new_outbox addObject:message];
            if (message.isFavourite)
                [new_favourites addObject:message];
            if ([message.author isEqualToString:myName])
                [new_myMessages addObject: message];
        }
        // Have to assign these one by one otherwise root tableView gets annoyed
        [self setOutboxMessages: new_outbox];
        [self setFavouriteMessages: new_favourites];
        [self setMyMessages:new_myMessages];
        self->_firstTimeInitPending = NO;
        self->_firstTimeInitialized = YES;
        NSLog(@"Finished async initialize");
    }];
}

// Return an array containing all message objects that were set up as outbox messages
- (NSMutableArray *) outbox
{
    if (!_firstTimeInitialized)
        [self asyncInitialize];
    return _outbox;
}

- (void)setOutboxMessages:(NSMutableArray*)messages
{
    _outbox = messages;
}

- (void)addOutboxMessagesObject:(CIXMessage*)message
{
    if (!_firstTimeInitialized) {
        NSLog(@"Error: tried to add outbox message before initialization");
        return;
    }
    if (![self.outbox containsObject:message])
        [self.outbox addObject:message];
}

- (void)removeOutboxMessagesObject:(CIXMessage*)message
{
    [self.outbox removeObject:message];
}

- (NSArray*)outboxMessages
{
    return [self.outbox copy];
}

- (NSUInteger)outboxMessageCount
{
    return [self.outbox count];
}

- (NSUInteger)outboxMessageCountToUpload
{
    NSUInteger count = 0;
    for (CIXMessage *message in self.outbox)
        if (!message.isHeld)
            count++;
    return count;
}

#pragma mark - Favourites

- (void)setFavouriteMessages:(NSMutableArray*)messages
{
    _favourites = messages;
}

// Return an array containing all message objects that were set up as outbox messages
- (NSMutableArray *) favourites 
{
    if (!_firstTimeInitialized)
        [self asyncInitialize];
    return _favourites;
}

- (void)toggleFavouriteMessage:(id<GenericMessage>)message
{
    if (!_firstTimeInitialized) {
        NSLog(@"Error: tried to toggle favourite message before initialization");
        return;
    }
    [self willChangeValueForKey:@"favouriteMessages"];
    message.isFavourite = !message.isFavourite;
    if (message.isFavourite) {
        if (![self.favourites containsObject:message])
            [self.favourites addObject:message]; 
    } else 
        [self.favourites removeObject:message]; 
    [self didChangeValueForKey:@"favouriteMessages"];
}

- (NSArray*)favouriteMessages
{
    return [self.favourites copy];
}

- (NSUInteger)favouriteMessageCount
{
    return [self.favourites count];
}

#pragma mark - My Messages

// Return an array containing all messages that I have posted
- (NSMutableArray *) myMessagesNonCopy
{
    if (!_firstTimeInitialized)
        [self asyncInitialize];
    return _myMessages;
}

- (void)setMyMessages:(NSMutableArray*)messages
{
    _myMessages = messages;
}

- (NSArray*)myMessages
{
    return [self.myMessagesNonCopy copy];
}

- (NSUInteger)myMessageCount
{
    return [self.myMessagesNonCopy count];
}

// New messages from myself are added at the beginning so they remain in order
- (void)addMyMessagesObject:(CIXMessage*)message
{
    NSInteger index=[_myMessages indexOfObject:message];
    if (NSNotFound == index) {
        [_myMessages insertObject:message atIndex:0];
    }
}

// Pop up an alert for the user
- (void)fireLocalNotification:(CIXMessage*)message
{
    // If we fire when active then it just runs the callback. Need to build our own UI FIXME
    if ([UIApplication sharedApplication].applicationState == UIApplicationStateActive)
        return;
    UILocalNotification *note = [[UILocalNotification alloc] init];
    if ([note respondsToSelector:@selector(setAlertTitle:)]) { // New in IOS 8.2
        note.alertTitle = message.summary;
    }
    note.alertBody = [NSString stringWithFormat:@"%@: %@", message.author, [message firstLineWithMaxLength:100]];
    note.userInfo = @{@"link": message.cixLink};
    [[UIApplication sharedApplication] presentLocalNotificationNow:note];
}

// Called (on main thread) when a set of new messages is read in
// all messages must be from the same topic
- (void)notifyTopicID: (NSManagedObjectID *)topicID newMessages: (NSArray*)msgIDs counts:(struct ParserCounts)counts {
    Topic* topic = [self.managedObjectContext objectWithID:topicID];;
    NSLog(@"notifyNewMessages: %lu messages", (unsigned long)msgIDs.count);
    for (NSManagedObjectID *messageObjectID in msgIDs) {
        CIXMessage *message = (CIXMessage*) [self.managedObjectContext objectWithID:messageObjectID];
        if ([message.author isEqualToString: [iXolrAppDelegate singleton].CIXusername]) {
            [self addMyMessagesObject:message];
            if ([iXolrAppDelegate singleton].settings.myMessagesAutoread && !message.isRead) {
                message.isRead = true;
                counts.interesting--;
                counts.unread--;
            }
        } else if (message.isInteresting && !message.isRead && !message.isIgnored) {
            [self fireLocalNotification:message];
        }
        if ([iXolrAppDelegate singleton].settings.uploadStars)
            if (message.isFavourite != [self.favourites containsObject:message])
                [self toggleFavouriteMessage:message];
    }
    [topic notifyNew:counts.newmessages unread:counts.unread interesting:counts.interesting];
    NSLog(@"notifyNewMessages: finished");
}

#pragma mark -

+ (NSData*)JSONfromMessage:(CIXMessage*)message {
    return [Parser JSONfromMessage:message];
}

- (void)finishedUpdatingMessages
{
    [_parser finish];
    _parser = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshFinished" object:nil];
}

#pragma mark - Parsing

// When we call Forum.TopicThread.get, we receive JSON that looks just like the scratchpad, but
// it only has the first line of each message.  So we identify those messages we don't already
// hold locally and create operations to download those individually.
- (NSUInteger)requestMissingMessagesFromJSONData: (NSData*)jsondata {
    NSUInteger count = 0;
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *messages = results[@"Messages"];
        count = [messages count];
        if (count > 0) {
            NSDictionary *item = messages[0];
            NSString *confName = item[@"Forum"];
            NSString *topicName = item[@"Topic"];
            Topic *currentTopic = [self findOrCreateConference: confName Topic: topicName];
            NSMutableArray *messageIDs = [NSMutableArray arrayWithCapacity:count];
            for (item in messages)
            {
                NSString *idstr = item[@"ID"];
                NSInteger msgnum = [idstr integerValue];
                if ([currentTopic messageWithNumber:msgnum] == nil) 
                    [messageIDs addObject:@(msgnum)];
            }
            [[iXolrAppDelegate singleton] downloadMessages:messageIDs conf:currentTopic.conference.name topic:currentTopic.name];
        }
    }
    
    return count;
}


// Pass objectIDs of messages from background thread to main thread so GUI can be updated
- (void)notifyTopic: (Topic *)topic messages: (NSArray*)messageObjects dataHelper: (DataQueryHelper*)localQueryHelper counts:(struct ParserCounts)counts {
    if (counts.newmessages != 0 || counts.interesting != 0 || counts.unread != 0) {
        // Must save objects before the IDs are copied, otherwise they have temporary IDs.
        [localQueryHelper saveContext];
        NSMutableArray * msgIDs = [NSMutableArray arrayWithCapacity:messageObjects.count];
        for (NSManagedObject *message in messageObjects)
            [msgIDs addObject:message.objectID];
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{ [self notifyTopicID: topic.objectID newMessages:msgIDs counts:counts]; }];
    }
}

// Parse JSON data into messages, store new messages in database, return the number of messages read in
// NOTE: Called on a non-main thread.
- (NSInteger)updateMessagesFromJSONData: (NSData*)jsondata user: (NSString*) CIXusername returnLatest:(NSDate**)latest {
    NSUInteger msgCount = 0, parsedMsgCount = 0;     // Count of messages read in and messages parsed so far
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        DataQueryHelper *localQueryHelper = self;
        Parser *parser = [[Parser alloc] initWithDataQueryHelper:localQueryHelper];
        //NSNumber *count = results[@"Count"];
        NSArray *messages = results[@"Messages"];
        msgCount = [messages count];
        NSLog(@"createMessagesFromJSONData: received %lu messages", (unsigned long)msgCount);
        NSMutableArray *messageObjects = [NSMutableArray arrayWithCapacity:msgCount];
        Topic *currentTopic = nil;
        struct ParserCounts counts = {};
        NSInteger totalNewMessages = 0;
        for (NSDictionary *item in [messages sortedArrayUsingDescriptors: [Parser messageSortDescriptors]])
        {
            //NSLog(@"%@", item);
            Topic *topic = [parser parseTopicFromDictionary:item];
            if (currentTopic != topic) {
                [self notifyTopic: currentTopic messages:messageObjects dataHelper:localQueryHelper counts: counts];
                currentTopic = topic;
                [messageObjects removeAllObjects];
                totalNewMessages += counts.newmessages;
                memset(&counts, 0, sizeof(counts));
            }
            CIXMessage* message = [parser parseMessageFromDictionary:item interestingUser:CIXusername counts: &counts];
            if (message != nil) {
                [messageObjects addObject:message];
            }
            parsedMsgCount += 1;
            if (latest != nil) {
                NSString *dateStr = item[@"LastUpdate"];
                if (dateStr != nil) {
                    NSDate *updated = [parser parseDate:dateStr];
                    if (*latest == nil || [*latest compare: updated] == NSOrderedAscending)
                        *latest = updated;
                }
            }
            if (parsedMsgCount % 10 == 0) {
                float progress = (float)parsedMsgCount / (float)msgCount * 0.5 + 0.5;  // Network download is half of progress; parsing is second half
                // Post notification on main thread to inform GUI to update
                [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"refreshProgress" object:@(progress)];
                }];
            }
        }
        [parser finish];
        [self notifyTopic: currentTopic messages:messageObjects dataHelper:localQueryHelper counts: counts];
        totalNewMessages += counts.newmessages;
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [[NSNotificationCenter defaultCenter] postNotificationName:@"newMessages" object:[NSNumber numberWithInteger: totalNewMessages]];
        }];
        NSLog(@"createMessagesFromJSONData: finished");
    }

    return msgCount;
}

- (NSArray*)confListFromJSONData: (NSData*)jsondata 
{
    NSMutableArray *array = [[NSMutableArray alloc] initWithCapacity:20];
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *forums = results[@"Forums"];
        for (NSDictionary *item in forums)
        {
            NSString *confName = item[@"Name"];
            [array addObject:confName];
        }
    }
    return array;
}

- (void)updateUnreadFromJSONData: (NSData*)jsondata underOperation: (NSOperation*)op
{
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *topics = results[@"Pointers"];
        NSLog(@"Sync CoSy pointers: received info on %lu topics", (unsigned long)[topics count]);
        float total = [topics count];
        int n = 1;
        for (NSDictionary *item in topics)
        {
            [[iXolrAppDelegate singleton] popupActivityIndicatorProgress:(n++ / total)];
            NSString *confName = item[@"Forum"];
            Conference *conf = [self conferenceWithName: confName];
            if (conf != nil) {
                NSString *topicName = item[@"Topic"];
                Topic *topic = [conf topicWithName: topicName];
                if (topic != nil && ![op isCancelled]) {
                    NSNumber *pointer = item[@"Pointer"];
                    [topic setMessagesUnreadUpToMsgnum:[pointer integerValue] ];
                }
            }
        }
        NSLog(@"Sync CoSy pointers: finished updating messages");
    }
}

- (void)updateTopicsInConference: (NSString*)confName fromJSONData: (NSData*)jsondata
{
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *messages = results[@"UserTopics"];
        Topic *topic = nil;
        for (NSDictionary *item in messages)
        {
            NSString *status = item[@"Status"];
            if ([status isEqualToString:@"A"])
                continue;
            NSString *topicName = item[@"Name"];
            topic = [self findOrCreateConference:confName Topic:topicName];
            NSString *flagsStr = item[@"Flag"];
            int32_t flags = [flagsStr isEqualToString:@"R"] ? TopicFlagsReadOnly : TopicFlagsNone;
            if ((flags & topic.flags) != flags) {
                topic.flags = flags;
                // Claim that we changed the messages even though we didn't - just need to get listeners to redraw
                [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:topic];
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:@"changedConference" object:topic.conference];
    }
}

// Parse user/topics result and return number of messages stated for a topic.  Return -1 if not found, or -2 if topic has been archived.
- (NSInteger) maxMessageNumForTopic:(NSString*)topicName fromJSONData: (NSData*)jsondata
{
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *messages = results[@"UserTopics"];
        for (NSDictionary *item in messages)
        {
            NSString *thisTopicName = item[@"Name"];
            if ([topicName isEqualToString:thisTopicName]) {
                NSString *status = item[@"Status"];
                if ([status isEqualToString:@"A"])
                    return -2;
                NSString *msgs = item[@"Msgs"];
                return [msgs integerValue];
            }
        }
    }
    return -1;
}

- (NSInteger) maxMessageNumForTopic2:(NSString*)topicName fromJSONData: (NSData*)jsondata
{
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *messages = results[@"Topics"];
        for (NSDictionary *item in messages)
        {
            NSString *thisTopicName = item[@"Name"];
            if ([topicName isEqualToString:thisTopicName]) {
                NSString *msgs = item[@"MaxID"];
                return [msgs integerValue];
            }
        }
    }
    return -1;
}

// Parse JSON for CIX top-level conference directory.  This arrives as pairs of category/subcategory names,
// and I want to use it as an array of (name plus array of subcategories)
- (NSArray*)directoryCategoriesFromJSONData: (NSData*)jsondata 
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:20];
    CIXCategory *lastCat = nil;
    NSMutableArray *subCategories = nil;
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *categories = results[@"Categories"];
        for (NSDictionary *item in categories)
        {
            NSString *name = item[@"Name"];
            if (lastCat == nil || ![name isEqualToString:lastCat.name])
            {
                lastCat = [[CIXCategory alloc] init];
                lastCat.name = name;
                subCategories = [NSMutableArray arrayWithCapacity:10];
                lastCat.subCategories = subCategories;
                [array addObject:lastCat];
            }
            [subCategories addObject:item[@"Sub"]];
        }
    }
    return array;
}

// Parse JSON for CIX conference directory info for one category.  This arrives as sets of info,
// and I want to break it down by subcategory and use it as an array of (name plus array of forum info)
- (NSArray*)directoryCategoryForumsFromJSONData: (NSData*)jsondata 
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:20];
    CIXSubCategory *lastCat = nil;
    NSMutableArray *forums = nil;
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *categories = results[@"Forums"];
        for (NSDictionary *item in categories)
        {
            NSString *name = item[@"Sub"];
            if (lastCat == nil || ![name isEqualToString:lastCat.name])
            {
                lastCat = [[CIXSubCategory alloc] init];
                lastCat.name = name;
                forums = [NSMutableArray arrayWithCapacity:10];
                lastCat.forums = forums;
                [array addObject:lastCat];
            }
            [forums addObject:item];
        }
    }
    return array;
}

// Parse JSON for CIX private messages
- (NSArray*)privateMessagesFromJSONData: (NSData*)jsondata
{
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:20];
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *conversations = results[@"Conversations"];
        for (NSDictionary *item in conversations)
        {
            NSString *body = item[@"Body"];
            [array addObject:body];
        }
    }
    return array;
}

// Parse JSON for CIX starred messages
- (NSArray*)starredMessagesFromJSONData: (NSData*)jsondata
{
    NSMutableArray *starredAtCIX = [NSMutableArray arrayWithCapacity:20];
    id results = [Parser parseJSONtoDictionary:jsondata];
    if ([results isKindOfClass:[NSDictionary class]])
    {
        NSArray *messages = results[@"Stars"];
        for (NSDictionary *item in messages)
        {
            Topic *topic = [self findOrCreateConference: item[@"Conf"] Topic: item[@"Topic"]];
            NSInteger msgnum = [item[@"MsgID"] integerValue];
            id<GenericMessage> message = [topic messageWithNumber:msgnum];
            if (message == nil)
                message = [PlaceholderMessage placeholderWithTopic:topic msgnum:msgnum];
            [starredAtCIX addObject: message];
        }
    }
    return starredAtCIX;
}

#pragma mark - Data object utility methods

- (NSArray *)executeFetchRequest: (NSFetchRequest*)fetchRequest
{
    NSError *error = nil;
    NSArray * results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (results == nil || error != nil)
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    return results;
}

// Return an array containing all topic objects in the database
- (NSArray *)fetchAllTopics
{
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Topic" inManagedObjectContext:self.managedObjectContext]];
    [fetchRequest setReturnsObjectsAsFaults:NO];    // We are going to look at all the objects so don't bother faulting them
    
    NSArray * results = [self executeFetchRequest:fetchRequest];
    

    return results;
}

- (NSInteger) countMessagesInTopic:(Topic*)topic
{
    return [self executeSimpleFunction:@"count:" onEntity:@"Message" forKeyPath:@"msgnum" withPredicate:[NSPredicate predicateWithFormat:@"(topic == %@)", topic]];
}

- (NSInteger) countUnReadMessagesInTopic:(Topic*)topic
{
    return [self executeSimpleFunction:@"count:" onEntity:@"Message" forKeyPath:@"msgnum" withPredicate:[NSPredicate predicateWithFormat:@"(topic == %@) AND ((isRead == NO) AND ((flags&16)!=16))", topic]]; // Counting ignored messages (bitmask=16) as read
}

- (NSInteger) countInterestingMessagesInTopic:(Topic*)topic
{
    return [self executeSimpleFunction:@"count:" onEntity:@"Message" forKeyPath:@"msgnum" withPredicate:[NSPredicate predicateWithFormat:@"(topic == %@) AND ((isRead == NO) AND ((flags&17)=1))", topic]]; // Unread, interesting and not ignored
}

// Do a single query which gets all message and unread counts across all topics
- (void) fetchAllTopicCounts
{
    NSLog(@"begin %s", __func__);
    NSArray *allTopics = [self fetchAllTopics];
    if (allTopics == nil || allTopics.count == 0)
        return; // No topics - nothing to do
    
    for (Topic *topic in allTopics) {
        [topic setCachedUnreadCount:0];
        [topic setCachedInterestingCount:0];
        [topic setCachedMessageCount:0];
    }
    
    [self saveContext]; // Need to save any pending changes, otherwise the result of the query will be wrong.

    sqlite3 *database = NULL;
    if (sqlite3_open([[[self storeURL] relativePath] UTF8String], &database) != SQLITE_OK) {
        NSLog(@"DB Error: %s", sqlite3_errmsg(database));
    }
    else {
        Topic *firstTopic = allTopics[0];
        // Get the base URI of Topic objects so we can hack around with it later
        NSURL *urlbasepath = [[firstTopic.objectID URIRepresentation] URLByDeletingLastPathComponent];
        // We fetch the count of message rows, also the sum of messages which are not read and not ignored
        const char *sql = "SELECT t0.ztopic, COUNT(*), SUM( (t0.ZISREAD = 0) AND ( (t0.ZFLAGS & 16) = 0)), SUM((t0.ZISREAD=0) AND (t0.ZFLAGS&17)=1) FROM zmessage t0 GROUP BY ZTOPIC";
        sqlite3_stmt *count_statement = NULL;
        if (sqlite3_prepare_v2(database, sql, -1, &count_statement, NULL) != SQLITE_OK) {
            NSLog(@"DB Error: %s", sqlite3_errmsg(database));
        } else {
        while ( sqlite3_step(count_statement) == SQLITE_ROW) {
            int topicID = sqlite3_column_int(count_statement, 0);
            int msgcount = sqlite3_column_int(count_statement, 1);
            int unreadcount = sqlite3_column_int(count_statement, 2);
            // Find the topic object by undocumented fiddling with URLs
            NSURL *topicUrl = [urlbasepath URLByAppendingPathComponent:[NSString stringWithFormat:@"p%d", topicID]];
            NSManagedObjectID *topicManagedObjectID = [self.persistentStoreCoordinator managedObjectIDForURIRepresentation:topicUrl];
            Topic *topic = (Topic*) [self.managedObjectContext objectWithID:topicManagedObjectID];
            [topic setCachedMessageCount:msgcount];
            [topic setCachedUnreadCount:unreadcount];
            [topic setCachedInterestingCount:sqlite3_column_int(count_statement, 3)];
        }
        }
    }
    sqlite3_close(database);

    [self recomputeTotalUnread];
    NSLog(@"end %s", __func__);
}

// Return an array containing all conference objects in the database
- (NSArray *)fetchAllConferences
{
    NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Conference"];
    
    // Read records in defined order, followed by alphabetical order by conference name.
    NSArray *sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"ordering" ascending:YES],
                                [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    [fetchRequest setReturnsObjectsAsFaults:NO];    // We are going to look at all the objects so don't bother faulting them
    [fetchRequest setRelationshipKeyPathsForPrefetching:@[@"topics"]];   // Also fetch related topics
    
    NSError *error = nil;
    NSArray * results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (results == nil || error != nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    // Hold on to the results so they will be cached next time we run the query
    _conferences = results;
    
    return results; // Already autoreleased
}

// Look for the next topic which has some unread messages, starting from a given topic.
- (Topic*)nextTopicWithUnreadAfter:(Topic*)topic
{
    // Look at the sibling topics of the given topic first
    Topic *next = [topic.conference firstTopicWithUnreadMessagesAfter:topic];
    if (next == nil)
    {
        NSArray *conferences = [self fetchAllConferences];
        NSUInteger start = topic ? [conferences indexOfObject:topic.conference] + 1 : 0;
        for (NSUInteger index = 0; index < [conferences count]; ++index)
        {
            Conference *conf = conferences[(start+index)%conferences.count];
            next = [conf firstTopicWithUnreadMessagesAfter:nil];
            if (next != nil)
                break;
        }
    }
    return next;
}

- (Topic*)nextInterestingTopicAfter:(Topic*)topic
{
    Topic *next = [topic.conference firstTopicWithInterestingMessagesAfter:topic];
    if (next == nil)
    {
        NSArray *conferences = [self fetchAllConferences];
        NSUInteger start = topic ? [conferences indexOfObject:topic.conference] + 1: 0;
        for (NSUInteger index = 0; index < [conferences count]; ++index)
        {
            Conference *conf = conferences[(start+index)%conferences.count];
            next = [conf firstTopicWithInterestingMessagesAfter:nil];
            if (next != nil)
                break;
        }
    }
    return next;
}

- (CIXMessage*)createNewOutboxMessage:(CIXMessage*)origMessage topic:(Topic*)topic
{
    CIXMessage *message = [self createNewMessage];
    message.isOutboxMessage = YES;
    message.isRead = YES;
    if (origMessage != nil)
    {
        message.topic = origMessage.topic;
        message.commentTo = origMessage.msgnum;
    }
    else
    {
        message.topic = topic;
    }
    [topic notifyNew:1 unread:0 interesting:0];
    // Find the highest message number currently in the outbox, so we can make sure this new one is numbered uniquely
    int highestOutboxMsgnum = 0;
    for (CIXMessage* outboxMsg in self.outboxMessages)
        if (outboxMsg.msgnum > highestOutboxMsgnum)
            highestOutboxMsgnum = outboxMsg.msgnum;
    if (highestOutboxMsgnum >= message.msgnum)
        message.msgnum = highestOutboxMsgnum + 1;
    return message;
}

// Carefully delete one message object and tell everyone who needs to know
- (void)deleteMessage:(CIXMessage*)message
{
    NSLog(@"Delete message at %p", message);
    if (message == nil)
        return; // Something has gone badly wrong
    if ([_outbox containsObject:message])
        [self removeOutboxMessagesObject:message];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"willDeleteMessage" object:message];
    Topic *topic = message.topic;
    [topic notifyMessageRemoved:message];
    message.topic = nil;    // Make sure this message doesn't show up in the topic any more
    [self.managedObjectContext deleteObject:message];
    [self saveContextAndHandleError];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:topic];
}

// Delete several message objects, assuming everyone who needs to know will be notified later
- (void) deleteMessagesInArray: (NSArray*)array fromPos: (NSUInteger)start toPos: (NSUInteger)end
{
    for (NSUInteger i = start; i < end; ++i) {
        id<GenericMessage> message = array[i];
        if (!message.isPlaceholder) {
            [message.topic notifyMessageRemoved:(CIXMessage*)message];
            [self.managedObjectContext deleteObject: (CIXMessage*)message];
        }
    }
}

- (void)deleteConference:(Conference*)conf
{
    [[NSNotificationCenter defaultCenter] postNotificationName:@"willDeleteMessage" object:nil];    // Notify that we will be deleting a lot of messages.
    // Delete all messages belonging to this conference.  
    // Messages are modeled as a one-way relationship so we have to do them; topics are two-way so will get deleted automatically
    for (Topic* topic in conf.topics)
        for (CIXMessage *message in [self messagesInTopic:topic])
            [self.managedObjectContext deleteObject:message];
    [self.managedObjectContext deleteObject:conf];
    [self saveContextAndHandleError];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"changedConference" object:nil];
}

// Fetch all messages in a topic, in no particular order
- (NSArray*)messagesInTopic:(Topic*)topic
{
    NSFetchRequest *fetchRequest = [self allocFetchRequestForEntity:@"Message"];
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"topic=%@", topic]];
    NSError *error = nil;
    NSArray *fetchedItems = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedItems == nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    return fetchedItems;
}

// Fetch all messages in a topic, in order by message number, ready for threading
- (NSArray*)messagesSortedForThreadingInTopic:(Topic*)topic
{
    NSFetchRequest *fetchRequest = [self allocFetchRequestForEntity:@"Message"];
    
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"topic=%@", topic]];

    {
        // Only fetch a few of the attributes on the objects, to begin with
        NSDictionary *props = fetchRequest.entity.propertiesByName;
        [fetchRequest setPropertiesToFetch:@[props[@"msgnum"], props[@"commentTo"], props[@"isRead"], props[@"flags"]]];
    }
    
    {
        // Read records in order by message number.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"msgnum" ascending:YES];
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        [fetchRequest setSortDescriptors:sortDescriptors];
    }
    
    NSError *error = nil;
    NSArray *fetchedItems = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedItems == nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    return fetchedItems;
}

// Fetch all messages in a topic, in descending order by message number
- (NSArray*)messagesSortedByMsgnumDesc:(Topic*)topic
{
    NSFetchRequest *fetchRequest = [self allocFetchRequestForEntity:@"Message"];
    
    [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"topic=%@", topic]];
    
    // Only fetch a few of the attributes on the objects, to begin with
    NSDictionary *props = fetchRequest.entity.propertiesByName;
    [fetchRequest setPropertiesToFetch:@[props[@"msgnum"]]];
    
    {
        // Read records in descending order by message number.
        NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"msgnum" ascending:NO];
        NSArray *sortDescriptors = [[NSArray alloc] initWithObjects:sortDescriptor, nil];
        [fetchRequest setSortDescriptors:sortDescriptors];
    }
    
    NSError *error = nil;
    NSArray *fetchedItems = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (fetchedItems == nil || error != nil)
    {
        NSLog(@"fetch request resulted in an error %@, %@", error, [error userInfo]);
    }
    return fetchedItems;
}

#pragma mark - Large-scale updates

- (void)markReadOlderThanDate:(NSDate*)date
{
    [[iXolrAppDelegate singleton] popupActivityIndicatorWithTitle:@"Marking messages as read"];
    UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];   // Tell IOS we want this to finish
    NSArray *conferences = [self fetchAllConferences];
    int n = 0;
    const float total = [conferences count];
    for (Conference *conf in conferences) 
    {
        ++n;
        [[NSOperationQueue mainQueue] addOperation: [CancellableBlockOperation operationWithBlock:^(NSOperation* op){
            [[iXolrAppDelegate singleton] popupActivityIndicatorProgress:n / total];
            for (Topic *topic in conf.topics) 
                if (![op isCancelled])
                    [topic markAllMessagesReadOlderThanDate:date];
        }]];
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[iXolrAppDelegate singleton] popdownActivityIndicator];
        [self saveContextAndHandleError];
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    }];
}

// Scan for duplicate topics; if we see any then rewrite its messages to a single topic
- (void) cleanUpTopics
{
    NSLog(@"Scanning for invalid topic entries...");
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:[NSEntityDescription entityForName:@"Topic" inManagedObjectContext:self.managedObjectContext]];
    [fetchRequest setReturnsObjectsAsFaults:NO];    // We are going to look at all the objects so don't bother faulting them
    [fetchRequest setSortDescriptors:@[
                                       [NSSortDescriptor sortDescriptorWithKey:@"conference" ascending:YES],
                                       [NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES],
                                       ]];
    
    NSArray * results = [self executeFetchRequest:fetchRequest];
    
    Topic *lastTopic = nil;
    for (Topic *topic in results) {
        if (lastTopic != nil && topic.conference == lastTopic.conference && [topic.name isEqualToString: lastTopic.name]) {
            NSLog(@"Moving messages from duplicate topic %@", topic);
            for (CIXMessage *message in [self messagesInTopic:topic])
                if ([self messageWithNumber:message.msgnum_int inTopic:lastTopic] == nil)
                    message.topic = lastTopic;
                else
                    [self.managedObjectContext deleteObject:message];
            [self.managedObjectContext deleteObject:topic];
        } else {
            lastTopic = topic;
        }
    }
    [self saveContextAndHandleError];
    NSLog(@"Finished scanning for invalid topic entries.");
}

- (void)purgeOlderThanDate:(NSDate*)date
{
    [[iXolrAppDelegate singleton] popupActivityIndicatorWithTitle:@"Erasing older messages"];
    UIBackgroundTaskIdentifier taskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:nil];   // Tell IOS we want this to finish
    [self cleanUpTopics];
    NSArray *conferences = [self fetchAllConferences];
    int n = 0;
    const float total = [conferences count];
    for (Conference *conf in conferences) 
    {
        ++n;
        [[NSOperationQueue mainQueue] addOperation: [CancellableBlockOperation operationWithBlock:^(NSOperation* op){
            [[iXolrAppDelegate singleton] popupActivityIndicatorProgress:n / total];
            for (Topic *topic in conf.topics) 
                if (![op isCancelled])
                    [topic purgeThreadsOlderThanDate:date];
        }]];
    }
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[iXolrAppDelegate singleton] popdownActivityIndicator];
        [self saveContextAndHandleError];
        [[UIApplication sharedApplication] endBackgroundTask:taskIdentifier];
    }];
}

- (NSURL*)storeURL
{
    return [[[iXolrAppDelegate singleton] applicationDocumentsDirectory] URLByAppendingPathComponent:@"iXolr.sqlite"];    
}

-(void)resetManagedObjectMembers
{
    __persistentStoreCoordinator = nil;
    __managedObjectContext = nil;
}

-(void)deleteMessageStore
{
                NSLog(@"Deleting message store");
                // delete the existing store
                [[NSFileManager defaultManager] removeItemAtURL:[self storeURL] error:nil];
                // repeat the opening procedure
                [self resetManagedObjectMembers];
                [self persistentStoreCoordinator];
}

#pragma mark - Core Data

// This override ensures that managedObjectContext is initialized before doing anything on the singleton class.
// It relies on the fact that this method is called before anything else in all functions that use managedObjectContext,
// which is true as of the time of writing but essentially accidental.
- (NSFetchRequest*)allocFetchRequestForEntity: (NSString*)entityName
{
    [self managedObjectContext];
    return [super allocFetchRequestForEntity:entityName];
}

/**
 Returns the managed object context for the application.
 If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
 */
- (NSManagedObjectContext *)managedObjectContext
{
    if (__managedObjectContext != nil)
    {
        return __managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil)
        [self initializeWithPersistentStoreCoordinator:coordinator];
    return __managedObjectContext;
}

/**
 Returns the managed object model for the application.
 If the model doesn't already exist, it is created from the application's model.
 */
- (NSManagedObjectModel *)managedObjectModel
{
    if (__managedObjectModel != nil)
    {
        return __managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"iXolr" withExtension:@"momd"];
    __managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];    
    return __managedObjectModel;
}

- (long long)persistentStoreSize
{
    NSError *error = nil;
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath: [self storeURL].path error:&error];

    return attrs.fileSize;
}

/**
 Returns the persistent store coordinator for the application.
 If the coordinator doesn't already exist, it is created and the application's store added to it.
 */
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (__persistentStoreCoordinator != nil)
    {
        return __persistentStoreCoordinator;
    }
    
    NSURL *storeURL = [self storeURL];
    // delete the existing store
    //[[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil];
    
    NSError *error = nil;
    __persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    //NSDictionary *pragmaOptions = nil; //[NSDictionary dictionaryWithObjectsAndKeys:@"50", @"cache_size", nil];
    // Ask for lightweight schema migration
    NSDictionary *options = @{NSMigratePersistentStoresAutomaticallyOption: @YES, NSInferMappingModelAutomaticallyOption: @YES, /*NSSQLitePragmasOption: pragmaOptions*/};

    if ([self persistentStoreSize] > 1000000) { // going to be a while loading - pop up an indicator
        [[iXolrAppDelegate singleton] popupActivityIndicatorWithTitle:@"Loading data..." cancellable:NO];
        // Using performSelector: to get this done when we get back to the main event loop
        [[iXolrAppDelegate singleton] performSelector:@selector(popdownActivityIndicator) withObject:nil afterDelay:0.1];
    }

    if (![__persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
    {
        NSLog(@"Error in addPersistentStoreWithType %@, %@", error, [error userInfo]);
        NSString *str = [NSString stringWithFormat:@"Unable to open messagebase: error message %@.  \nIf you delete the messagebase you will lose any messages downloaded from CIX, although you should be able to re-download them.  Hit the Home button if you want to quit iXolr without deleting anything", [error localizedDescription]];
        [[iXolrAppDelegate singleton] confirm:str title:@"Error opening messagebase" actionTitle:@"Delete messagebase" ifConfirmed:^{
            [self deleteMessageStore];
        }];
    }    
    
    return __persistentStoreCoordinator;
}


// Invoke the SQLite Vacuum command, to pack up all pages and reindex all tables
- (void)VacuumStore
{
    [[iXolrAppDelegate singleton] popupActivityIndicatorWithTitle:@"Compacting Database..." cancellable:NO];
    [[NSOperationQueue mainQueue] addOperation: [CancellableBlockOperation operationWithBlock:^(NSOperation* op){
    NSURL *storeURL = [self storeURL];
    
    NSError *error = nil;
    NSPersistentStoreCoordinator *newPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    NSDictionary *pragmaOptions = @{@"cache_size": @"50"};
    // Ask for lightweight schema migration
    NSDictionary *options = @{NSSQLiteManualVacuumOption: @YES, NSInferMappingModelAutomaticallyOption: @YES, NSSQLitePragmasOption: pragmaOptions};
    
        if (![newPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error])
        {
            NSLog(@"Error in VacuumStore %@, %@", error, [error userInfo]);
            NSString *str = [NSString stringWithFormat:@"A problem was reported during this operation: error message %@.  \nIf you delete the messagebase you will lose any messages downloaded from CIX, although you should be able to re-download them.  Hit the Home button if you want to quit iXolr without deleting anything", [error localizedDescription]];
            [[iXolrAppDelegate singleton] confirm:str title:@"Error compacting messagebase" actionTitle:@"Delete messagebase" ifConfirmed:^{
                [self deleteMessageStore];
            }];
        }
    }]];
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        [[iXolrAppDelegate singleton] popdownActivityIndicator];
    }];
}

@end

// CIX directory implementations
@implementation CIXCategory
@synthesize name;
@synthesize subCategories;
@end

@implementation CIXSubCategory
@synthesize name;
@synthesize forums;
@end

