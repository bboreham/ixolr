//
//  Topic.m
//  iXolr
//
//  Created by Bryan Boreham on 05/07/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "Topic.h"
#import "Conference.h"
#import "Message.h"
#import "iXolrAppDelegate.h"
#import "DataController.h"

NSInteger findBackwards(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *object);
void insertMessage(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, NSUInteger index);
NSUInteger insertMessageBeforeIndent(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, int indent, int msgnum, NSUInteger startPoint);
NSUInteger insertTopLevelMessage(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, int msgnum);

@implementation Topic {
@private
    NSInteger cachedUnreadCount;
    NSInteger cachedMessageCount;
    NSInteger cachedInterestingCount;
}
@dynamic name;
@dynamic conference;
@dynamic flags;
@dynamic topicDescr;

- (void) setOrClearFlag:(int)mask withBool:(BOOL) b
{
    if (b)
        self.flags |= mask;
    else
        self.flags &= (~mask);
}

- (BOOL) testFlag:(int)mask
{
    return (self.flags & mask) != 0;
}

- (void) setIsMute:(BOOL)isMute
{
    [self setOrClearFlag:TopicFlagsMute withBool:isMute];
}

- (BOOL)isMute
{
    return [self testFlag:TopicFlagsMute];
}

- (void)setIsReadOnly:(BOOL)isReadOnly
{
    [self setOrClearFlag:TopicFlagsReadOnly withBool:isReadOnly];
}

- (BOOL)isReadOnly
{
    return [self testFlag:TopicFlagsReadOnly];
}

- (void) setIsResigned:(BOOL)isResigned
{
    [self setOrClearFlag:TopicFlagsResigned withBool:isResigned];
}

- (BOOL)isResigned
{
    return [self testFlag:TopicFlagsResigned] ;
}

- (NSString *)fullName
{
    return [NSString stringWithFormat:@"%@/%@", self.conference.name, self.name];
}

- (NSString *)description
{
    return [self fullName];
}

// UNKNOWN means we will have to compute a count
#define UNKNOWN(x) (x<0)

- (void)invalidateCachedCounts
{
    cachedMessageCount = -1;
    [self invalidateCachedUnreadCounts];
}

- (void)invalidateCachedUnreadCounts
{
    cachedUnreadCount = -1;
    cachedInterestingCount = -1;
}

- (void) setCachedMessageCount: (NSInteger)count
{
    cachedMessageCount = count;
}

- (void) setCachedUnreadCount: (NSInteger)count
{
    cachedUnreadCount = count;
}

- (void) setCachedInterestingCount: (NSInteger)count
{
    cachedInterestingCount = count;
}

- (void)notifyNew: (NSInteger)newMessages unread: (NSInteger)unread interesting: (NSInteger)interesting
 {
     NSDictionary *dict = (UNKNOWN(cachedUnreadCount) || UNKNOWN(cachedInterestingCount)) ? nil : @{@"PreviousUnreadCount": @(cachedUnreadCount),
                                                               @"PreviousInterestingCount": @(cachedInterestingCount) };
    if (!UNKNOWN(cachedMessageCount))
        cachedMessageCount += newMessages;
    if (!UNKNOWN(cachedUnreadCount))
        cachedUnreadCount += unread;
    if (!UNKNOWN(cachedInterestingCount))
        cachedInterestingCount += interesting;
    if (unread != 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self userInfo:dict];
    if (newMessages != 0)
        [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:self];
}

- (void)notifyMessageRemoved:(CIXMessage *)value {
    if (!UNKNOWN(cachedMessageCount))
        --cachedMessageCount;
    if (!UNKNOWN(cachedUnreadCount) && !value.isRead && !value.isIgnored)
        --cachedUnreadCount;
    if (!UNKNOWN(cachedInterestingCount) && !value.isRead && !value.isIgnored && value.isInteresting)
        --cachedInterestingCount;
}

- (void) awakeFromInsert
{
    [super awakeFromInsert];
    cachedMessageCount = 0;     // At this point there are no child messages so these counts must be correct
    cachedUnreadCount = 0;
    cachedInterestingCount = 0;
}

- (void) awakeFromFetch
{
    [super awakeFromInsert];
    [self invalidateCachedCounts];
}

- (NSInteger) messageCount
{
    [self willAccessValueForKey:@"messageCount"];
    if (cachedMessageCount < 0)
        cachedMessageCount = [[iXolrAppDelegate singleton].dataController countMessagesInTopic: self];
    [self didAccessValueForKey:@"messageCount"];
    return cachedMessageCount;
}

- (NSInteger) messagesUnreadCount
{
    [self willAccessValueForKey:@"messagesUnreadCount"];
    if (cachedUnreadCount < 0)
        cachedUnreadCount = [[iXolrAppDelegate singleton].dataController countUnReadMessagesInTopic: self];
    [self didAccessValueForKey:@"messagesUnreadCount"];
    return cachedUnreadCount;
}

- (NSInteger) interestingMessagesCount
{
    [self willAccessValueForKey:@"interestingMessagesCount"];
    if (cachedInterestingCount < 0)
        cachedInterestingCount = [[iXolrAppDelegate singleton].dataController countInterestingMessagesInTopic: self];
    [self didAccessValueForKey:@"interestingMessagesCount"];
    return cachedInterestingCount;
}

- (CIXMessage*) messageWithNumber: (NSInteger)num
{
    return [[iXolrAppDelegate singleton].dataController messageWithNumber:num inTopic:self];
}

- (void) messageReadStatusChanged: (id<GenericMessage>)message
{
    NSDictionary *dict = (UNKNOWN(cachedUnreadCount) || UNKNOWN(cachedInterestingCount)) ? nil : @{
            @"PreviousUnreadCount": @(cachedUnreadCount),
            @"PreviousInterestingCount": @(cachedInterestingCount),
            @"SingleMessage": message };
    if (!UNKNOWN(cachedUnreadCount) && !message.isIgnored)
        if (message.isRead)
            cachedUnreadCount--;
        else
            cachedUnreadCount++;
    if (!UNKNOWN(cachedInterestingCount) && !message.isIgnored && message.isInteresting)
        if (message.isRead)
            --cachedInterestingCount;
        else
            ++cachedInterestingCount;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self userInfo:dict];
}

// Call after changing read status of multiple messages
- (void) messageMultipleReadStatusChanged
{
    NSDictionary *dict = (UNKNOWN(cachedUnreadCount) || UNKNOWN(cachedInterestingCount)) ? nil : @{
            @"PreviousUnreadCount": @(cachedUnreadCount),
            @"PreviousInterestingCount": @(cachedInterestingCount) };
    [self invalidateCachedCounts];
    [[iXolrAppDelegate singleton].dataController saveContext];
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self userInfo:dict];
}

- (void) markAllMessagesRead
{
    NSInteger prev = cachedUnreadCount;
    for (CIXMessage* message in [[iXolrAppDelegate singleton].dataController messagesInTopic:self])
    {
        if (message.isRead != YES)
            message.isRead = YES;
    }
    cachedUnreadCount = 0;
    cachedInterestingCount = 0;
    [[iXolrAppDelegate singleton].dataController saveContext];
    NSDictionary *dict = UNKNOWN(prev) ? nil : @{@"PreviousUnreadCount": @(prev)};
    [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self userInfo:dict];
}

- (void) markAllMessagesReadOlderThanDate:(NSDate*)compareDate
{
    int numChanged = 0;
    for (CIXMessage* message in [[iXolrAppDelegate singleton].dataController messagesInTopic:self])
    {
        if ([message.date compare:compareDate] == NSOrderedAscending) 
            if (message.isRead != YES) {
                message.isRead = YES;
                ++numChanged;
            }
    }
    if (numChanged > 0) {
        [self invalidateCachedUnreadCounts];
        [[iXolrAppDelegate singleton].dataController saveContext];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self];
    }
}

// Remove from the database all messages in threads where the entire thread is older than compareDate.
// Also leave any threads which have 'starred' or favourite messages.
- (void) purgeThreadsOlderThanDate:(NSDate*)compareDate
{
    int numChanged = 0;

    [[NSNotificationCenter defaultCenter] postNotificationName:@"willDeleteMessage" object:nil];    // Notify that we will be deleting a lot of messages.
    NSUInteger pos = 0, lastThreadPos = 0;
    BOOL foundNewerMessage = NO;
    NSArray *messagesThreaded = [self messagesThreaded];
    for (id<GenericMessage> message in messagesThreaded) {
        if (message.isPlaceholder || message.commentTo == 0) {    // Stop at each root message and deal with the whole thread
            if (foundNewerMessage == NO) {
                [[iXolrAppDelegate singleton].dataController deleteMessagesInArray:messagesThreaded fromPos:lastThreadPos toPos:pos];
                numChanged += (pos - lastThreadPos);
            }
            lastThreadPos = pos;
            foundNewerMessage = NO;
        }
        if (foundNewerMessage == NO && ([message.date compare:compareDate] == NSOrderedDescending || message.isFavourite)) 
            foundNewerMessage = YES;
        ++pos;
    }
    // Handle the last thread
    if (foundNewerMessage == NO) {
        [[iXolrAppDelegate singleton].dataController deleteMessagesInArray:messagesThreaded fromPos:lastThreadPos toPos:pos];
        numChanged += (pos - lastThreadPos);
    }
    if (numChanged > 0) {
        [self invalidateCachedUnreadCounts];
        [[iXolrAppDelegate singleton].dataController saveContext];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"changedMessagesInTopic" object:self];
    }
}

// Set the unread count to match some external value (e.g. to sync with CoSy), by marking messages read or unread as necessary
- (void) setMessagesUnreadUpToMsgnum:(NSInteger)msgnum
{
    int numChanged = 0;
    for (CIXMessage* message in [[iXolrAppDelegate singleton].dataController messagesInTopic:self])
    {
        BOOL read = (message.msgnum_int <= msgnum);
        if (message.isRead != read) {
            message.isRead = read;
            ++numChanged;
        }
    }
    if (numChanged > 0) {
        [self invalidateCachedUnreadCounts];
        [[iXolrAppDelegate singleton].dataController saveContext];
        [[NSNotificationCenter defaultCenter] postNotificationName:@"messageReadCountChanged" object:self];
    }
}

#pragma mark - Threading

/*
 Threaded Display:
 Suppose we have the following messages:
 1 root1
 2 root2
 3 comment to 1
 4 comment to 2
 5 comment to 3
 6 comment to 1
 Then we want to display them like this:
 1
   3
     5
   6
 2
   4

 So we want to create the ordering 1,3,5,6,2,4; and we want to compute the indentations (0,1,2,1,0,1).
 Also, although in this example the messages arrive in the correct order, 
 they may actually arrive in any order and there may be gaps in the ordering.
 
 Proposed algorithm:
 Create list.
 For each message,
    If it is a root message, insert between two other root messages with straddling numbers; indent zero.
    If it is a comment to another message, insert in correct spot after that message, with indent of that message + 1.
    If it is a comment to a message we don't have, treat as a root message.
    If it is the message that a previously-inserted message comments to, move that message and all descendents, and fix up indents.
 
 */

- (NSArray *)messagesThreaded
{
    NSArray *sortedMessages = [[iXolrAppDelegate singleton].dataController messagesSortedForThreadingInTopic:self];
    NSObject<GenericMessage> *__strong*messageArray = (NSObject<GenericMessage> *__strong*) calloc(sizeof(NSObject<GenericMessage> *), [sortedMessages count] * 2);  // Double because potentially every message has a placeholder original
    NSUInteger messageArray_count = 0;
    NSUInteger pos = 0; 
    
    NSInteger max_msgnum = ((CIXMessage*)[sortedMessages lastObject]).msgnum;
    // Create an array to cache the object pointer of each message against its message number as we place it
    NSObject<GenericMessage> *__strong*msgnumToMsg = (NSObject<GenericMessage> *__strong*) calloc(sizeof(NSObject<GenericMessage> *), max_msgnum+1);
    
    for (CIXMessage *msg in sortedMessages)
    {
        if (msg.msgnum == 0)
            continue;   // not a real message; ignore it
        int32_t commentTo = msg.commentTo;
        if (commentTo == 0) // No commentTo, so this is a root message.  Also it has a higher message number than anything seen so far, because we sorted them, so it inserts at the end
        {
            msg.indentTransient = 0;
            insertMessage(messageArray, &messageArray_count, msg, messageArray_count);
        }
        else {
            NSObject<GenericMessage> * commentToObj = msgnumToMsg[commentTo];
            NSInteger commentToPos = findBackwards(messageArray, &messageArray_count, commentToObj);
        if (commentToPos >= 0) 
        {   // We know where the commented-to message is
            id<GenericMessage> msgCommentedTo = messageArray [commentToPos];
            msg.indentTransient = msgCommentedTo.indentTransient + 1;
            insertMessageBeforeIndent(messageArray, &messageArray_count, msg, msg.indentTransient, msg.msgnum_int, commentToPos+1);
        }
        else    // Didn't find the one that this is a comment to - add a placeholder for that one and add this just after as a comment
        {
            NSObject <GenericMessage> *placeholder = [[PlaceholderMessage alloc] init]; 
            placeholder.msgnum = commentTo;
            placeholder.topic = self;
            placeholder.isRead = YES;
            pos = insertTopLevelMessage(messageArray, &messageArray_count, placeholder, commentTo);
            msgnumToMsg[commentTo] = placeholder;
            msg.indentTransient = 1;
            insertMessage(messageArray, &messageArray_count, msg, ++pos);
        }
        }
        msgnumToMsg[msg.msgnum] = msg;
    }
    free(msgnumToMsg);
    NSMutableArray *returnArray = [[NSMutableArray alloc] initWithCapacity:messageArray_count];
    for (pos = 0; pos < messageArray_count; ++pos) {
        [returnArray addObject:messageArray[pos]];
    }
    free(messageArray);
    return returnArray;
}

- (void)displayErrorMessage: (NSString*)message
{
    [[iXolrAppDelegate singleton] displayErrorMessage:message title:@"Topic error"];
}

- (void)downloadMissingMessages: (NSInteger)max
{
    [[iXolrAppDelegate singleton] popupActivityIndicatorWithTitle: @"Finding messages..."];
    [[iXolrAppDelegate singleton] getMaxMsgNumForConf:self.conference.name topic:self.name then: ^(NSInteger maxMsgNum) {
        NSMutableArray *msgids = [NSMutableArray arrayWithCapacity:max];
        if (maxMsgNum == -1)
            // Delay is to allow activity indicator to pop down
            [self performSelector:@selector(displayErrorMessage:) withObject:@"CIX does not show any information for this topic" afterDelay:0.5];
        else if (maxMsgNum == -2)
            [self performSelector:@selector(displayErrorMessage:) withObject:@"Topic has been archived at CIX; cannot download any messages" afterDelay:0.5];
        else {
            NSArray *sortedMessages = [[iXolrAppDelegate singleton].dataController messagesSortedByMsgnumDesc:self];
            NSInteger lastMsgnum = maxMsgNum+1;
            for (CIXMessage *msg in sortedMessages)
            {
                if (msg.isOutboxMessage)
                    continue;
                // Suppose lastMsgNum is 2841 and msg.msgnum is 2837.  Then I want to add 2840, 2839, 2838 to the array
                if (lastMsgnum > 0 && msg.msgnum != lastMsgnum-1)
                    for (NSInteger i = lastMsgnum-1; i > msg.msgnum && msgids.count < max; --i)
                        [msgids addObject:@(i)];
                if (msg.isPlaceholder)
                    [msgids addObject:@(msg.msgnum)];
                lastMsgnum = msg.msgnum;
            }
            for (NSInteger i = lastMsgnum-1; i > 0 && msgids.count < max; --i)
                [msgids addObject:@(i)];
        }
        if (msgids.count > 0)
            [[iXolrAppDelegate singleton] downloadMessages:msgids conf:self.conference.name topic:self.name];
        else
            [[iXolrAppDelegate singleton] popdownActivityIndicator];
    }];
}
@end

NSInteger findBackwards(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *object)
{
    for (NSInteger i = *count-1; i >= 0; --i)
        if (messageArray[i] == object)
            return i;
    return -1;
}

void insertMessage(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, NSUInteger index)
{
    for (NSUInteger i = *count; i > index; --i)
        messageArray[i] = messageArray[i-1];
    messageArray[index] = msg;
    *count += 1;
}

// Find the position in this array at or after startPoint where the message's indent is less than that given,
// or indent is the same as given and message number higher than msgnum, and insert the given message
NSUInteger insertMessageBeforeIndent(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, int indent, int msgnum, NSUInteger startPoint)
{
    NSUInteger j;
    for (j = startPoint; j < *count; ++j)
    {
        id <GenericMessage> thisMsg = messageArray[j];
        int thisIndent = thisMsg.indentTransient;
        if (thisIndent < indent)
            break;
        if ((thisIndent == indent) && (thisMsg.msgnum > msgnum))
            break;
    }
    insertMessage(messageArray, count, msg, j);
    return j;
}

// Insert msg at top level in the threading, either right at the end or before a top-level message that has a higher number than msgnum
NSUInteger insertTopLevelMessage(NSObject<GenericMessage> *__strong*messageArray, NSUInteger *count, NSObject<GenericMessage> *msg, int msgnum)
{
    NSUInteger j;
    for (j = 0; j < *count; ++j)
    {
        id <GenericMessage> thisMsg = messageArray[j];
        int thisIndent = thisMsg.indentTransient;
        if ((thisIndent == 0) && (thisMsg.msgnum > msgnum))
            break;
    }
    insertMessage(messageArray, count, msg, j);
    return j;
}

