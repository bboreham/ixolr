//
//  Parser.m
//  iXolr
//
//  Created by Bryan Boreham on 16/05/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "Parser.h"
#import "DataController.h"
#import "Topic.h"
#import "Message.h"
#import "Conference.h"
#import "StringUtils.h"

// NOTE: All the methods in this class may be called on non-main threads so must not call any GUI or singleton methods
@implementation Parser {
@private
    Topic *currentTopic;
    NSCalendar *CIXcalendar;
    DataQueryHelper *dataController;
}

- (id) initWithDataQueryHelper:(DataQueryHelper *)dc
{
	self = [super init];
	if (self) {
        dataController = dc;
        CIXcalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
        [CIXcalendar setTimeZone:[NSTimeZone timeZoneWithName:@"Europe/London"]];
    }
    return self;
}


#pragma mark - Serializing

// Link is something like "cix:foobar/general2:213"
+ (NSData*)JSONfromMessageLink:(NSString*)link {
    NSArray *components = [link componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@":/"]];
    if ([components count] == 4) {
        NSDictionary *dict = @{@"Forum": components[1],
                               @"Topic": components[2],
                               @"MsgID": components[3]};
        return [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    } else {
        return nil;
    }
}

+ (NSData*)JSONfromMessage:(CIXMessage*)message {
    NSDictionary *dict = @{@"Forum": message.topic.conference.name,
                          @"Topic": message.topic.name,
                          @"Body": message.text,
                          @"MsgID": @(message.commentTo)};
    return [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
}

+ (NSData*)JSONfromSearchQuery:(NSString*)query confName:(NSString*)confName author:(NSString*)author years:(NSInteger)years {
    NSDictionary *dict = @{@"Forum": confName,
                          @"Author": author,
                          @"Years": @(years),
                          @"Query": query};
    return [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
}

+ (NSData*)JSONfromSearchQuery:(NSString*)query {
    return [self JSONfromSearchQuery:query confName:@"" author:@"" years:0];
}

// Return JSON suitable for forum.messagerange request
+ (NSData*)JSONfromMessageNumbers:(NSArray*)messages conf:(NSString*)conf topic:(NSString*)topic
{
// e.g. { "Forum":"cixnews", "Topic":"announce", "Start":652, "End":661 }
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:[messages count]];
    for (NSNumber *msgnum in messages) {
        [array addObject: @{@"ForumName": conf,
                              @"TopicName": topic,
                              @"Start": msgnum,
                              @"End": msgnum} ];
    }
    return [NSJSONSerialization dataWithJSONObject:array options:0 error:nil];
}

int StringToTopicAndNum(NSString *link, NSString **topic) {
    NSArray *components = [link componentsSeparatedByString:@":"];
    *topic = components[1];
    return [components[2] intValue];
}

+ (NSData*)JSONRangesfromMessageLinks:(NSArray*) messages {
    NSArray *sortedMessages = [messages sortedArrayUsingSelector:@selector(compare:)];
    NSMutableArray *retvalue = [NSMutableArray arrayWithCapacity:messages.count];
    NSUInteger pos = 0;
    NSUInteger count = sortedMessages.count;
    do {
        NSString *currentConfTopic;
        int startNumber = StringToTopicAndNum(sortedMessages[pos], &currentConfTopic);
        int lastNumber = startNumber;
        NSUInteger endOfRun = pos+1;
        for (; endOfRun < count; ++endOfRun) {
            NSString *conftopic;
            int msgnum = StringToTopicAndNum(sortedMessages[endOfRun], &conftopic);
            if (![conftopic isEqualToString: currentConfTopic] || msgnum != lastNumber+1)
                break;
            else
                ++lastNumber;
        }
        NSArray *components = [currentConfTopic componentsSeparatedByString:@"/"];
        [retvalue addObject: @{@"ForumName":components[0], @"TopicName":components[1], @"Start":@(startNumber), @"End":@(lastNumber)}];
        pos = endOfRun;
    } while (pos < count);

    NSError *error = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:retvalue options:0 error:&error];
    if (error != nil)
        NSLog(@"JSON generation resulted in an error %@, %@", error, [error userInfo]);
    return data;
}

#pragma mark - Parsing

- (NSDate *) parseDate: (NSString *) datetimestr  {
    // Following Apple documentation's recommendation to 'Consider Unix Functions for Fixed-Format, Unlocalized Dates'
      struct tm  msgtm;
    memset(&msgtm, 0, sizeof(msgtm));
    strptime([datetimestr cStringUsingEncoding:NSASCIIStringEncoding], "%d/%m/%Y %H:%M:%S", &msgtm);
    NSDateComponents *datecomps = [[NSDateComponents alloc] init];
    [datecomps setDay:msgtm.tm_mday];
    [datecomps setMonth:msgtm.tm_mon+1];
    [datecomps setYear:msgtm.tm_year+1900];
    [datecomps setHour:msgtm.tm_hour];
    [datecomps setMinute:msgtm.tm_min];
    [datecomps setSecond:msgtm.tm_sec];
    NSDate *retval = [CIXcalendar dateFromComponents:datecomps];
    return retval;
}

// Copy the Interesting or Ignored flags to all later messages in the thread from this message, e.g. when backfilling
// NOTE this can be called on a non-main thread so must not let NSManagedObject instances cross thread boundaries
- (void) copyFlagsForward: (id<GenericMessage>) message withHelper: (DataQueryHelper*)helper
{
    if (!message.isInteresting && !message.isIgnored)
        return;
    NSArray *followUps = [helper messagesCommentingOn:message.msgnum inTopic:message.topic];
    for (CIXMessage* followUp in followUps) {
        if (message.isInteresting)
            followUp.isInteresting = YES;
        if (message.isIgnored)
            followUp.isIgnored = YES;
        [self copyFlagsForward:followUp withHelper:helper];
    }
}

- (Topic *) parseTopicFromDictionary:(NSDictionary*)item
{
    NSString *confName = item[@"Forum"];
    NSString *topicName = item[@"Topic"];
    if (confName == nil || topicName == nil) {
        NSLog(@"parseMessageFromDictionary failed: does not look like a message: %@", item);
        return nil;
    }
    if (![confName isEqualToString:currentTopic.conference.name] || ![topicName isEqualToString:currentTopic.name])
    {
        currentTopic = [dataController findOrCreateConference: confName Topic: topicName];
    }
    return currentTopic;
}

// Create a new autoreleased CIXMessage object populated with data in the supplied dictionary
// parseTopicFromDictionary must be called first
// NOTE this can be called on a non-main thread so must not let NSManagedObject instances cross thread boundaries
- (CIXMessage *) parseMessageFromDictionary:(NSDictionary*)item interestingUser:(NSString*)interestingUser counts:(struct ParserCounts*)counts
{
    NSString *idstr = item[@"ID"];
    
    int msgnum = [idstr intValue];
    CIXMessage *oldMessage = [dataController messageWithNumber:msgnum inTopic:currentTopic];
    CIXMessage *message = oldMessage ? oldMessage : [dataController createNewMessage];

    BOOL isRead = [self messageIsRead:item];
    //message.isStarred = [item[@"Starred"] boolValue];
    message.msgnum = msgnum;
    message.author = item[@"Author"];
    message.text = item[@"Body"];
    message.commentTo = [item[@"ReplyTo"] intValue];
    CIXMessage *orig = [dataController messageWithNumber:message.commentTo inTopic:currentTopic];
    // Note that if the original message cannot be found then orig will be nil and the properties come back as NO, which is OK for the way we use them
    BOOL isInteresting = ([message.author isEqualToString:interestingUser] || orig.isInteresting);
    //message.isInteresting = [item[@"Priority"] boolValue];
    //message.isWithdrawn = ![item[@"Flags"] isEqualToString:@"U"];
    message.isIgnored = oldMessage ? oldMessage.isIgnored : (orig.isIgnored || currentTopic.isMute);
    message.date = [self parseDate: item[@"DateTime"]];

    if (oldMessage == nil) {
        counts->newmessages++;
        counts->unread += !isRead && !message.isIgnored ? 1 : 0;
        counts->interesting += !isRead && isInteresting && !message.isIgnored ? 1 : 0;
    } else if (!message.isIgnored) { // note isIgnored does not change on a download
        if (isRead != oldMessage.isRead) {
            counts->unread += !isRead ? 1 : -1;
            if (oldMessage.isInteresting)
                counts->interesting += !isRead ? 1 : -1;
        }
        if (!isRead && isInteresting != oldMessage.isInteresting)
            counts->interesting += isInteresting ? 1 : -1;
    }
    message.isRead = isRead;
    message.isInteresting = isInteresting;
    
    message.topic = currentTopic;
    [self copyFlagsForward: message withHelper:dataController];
    
    NSLog(@"%@", message);
    return message;
}

- (BOOL) messageIsRead:(NSDictionary*)item
{
    if  (item[@"Status"] != nil)
        return [item[@"Status"] isEqualToString:@"R"];
    else if (item[@"Unread"] != nil)
        return ![item[@"Unread"] boolValue];
    return NO;
}

+ (NSArray*) messageSortDescriptors {
    return @[[NSSortDescriptor sortDescriptorWithKey:@"Forum" ascending:YES], [NSSortDescriptor sortDescriptorWithKey:@"Topic" ascending:YES]];
}

- (void) finish
{
    [dataController saveContext];
}

// Static method is here as convenience to callers who can't be bothered creating a Parser.
+ (NSDictionary*)parseJSONtoDictionary:(NSData*)jsondata
{
    NSError *error = nil;
    id results = [NSJSONSerialization JSONObjectWithData:jsondata options:0 error:&error];
    if (results == nil || error != nil)
    {
        NSLog(@"Data received: %@", [jsondata asUTF8String]);
        NSLog(@"JSON parsing resulted in an error %@, %@", error, [error userInfo]);
    }
    return results;
}

- (NSDictionary*)parseJSONtoDictionary:(NSData*)jsondata
{
    NSError *error = nil;
    id results = [NSJSONSerialization JSONObjectWithData:jsondata options:0 error:&error];
    if (results == nil || error != nil)
    {
        NSLog(@"Data received: %@", [jsondata asUTF8String]);
        NSLog(@"JSON parsing resulted in an error %@, %@", error, [error userInfo]);
    }
    return results;
}
@end
