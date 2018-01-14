//
//  Conference.m
//  iXolr
//
//  Created by Bryan Boreham on 23/12/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "Conference.h"
#import "Topic.h"

// Bitmask for values of flags property
typedef enum {
    MFnone = 0,
    MFinteresting=1,
    MFresigned=2,
} MessageFlagsType;


@implementation Conference

@dynamic name;
@dynamic flags;
@dynamic topics;
@dynamic moderators;
@dynamic ordering;

- (void) setOrClearFlag:(int)mask withBool:(BOOL) b
{
    if (b)
        self.flags |=  mask;
    else
        self.flags &= (~mask);
}

- (BOOL) testFlag:(int)mask
{
    return (self.flags & mask) != 0;
}

- (void) setIsResigned:(BOOL)isResigned
{
    [self setOrClearFlag:MFresigned withBool:isResigned];
}

- (BOOL)isResigned
{
    return [self testFlag:MFresigned] ;
}

- (NSInteger) messageCount
{
    NSUInteger messageCount = 0;
    for (Topic *topic in self.topics) 
        messageCount += topic.messageCount;
    return messageCount;
}

- (NSInteger) messagesUnreadCount
{
    NSInteger messageUnreadCount = 0;
    for (Topic *topic in self.topics) 
        messageUnreadCount += topic.messagesUnreadCount;
    return messageUnreadCount;
}

- (NSInteger) interestingMessagesCount
{
    NSUInteger count = 0;
    for (Topic *topic in self.topics)
        count += topic.interestingMessagesCount;
    return count;
}

- (Topic*)topicWithName:(NSString*)name
{
	for (Topic *topic in [self topics]) {
		if ([topic.name compare:name] == NSOrderedSame)
            return topic;
	}
    //NSLog(@"Failed to find topic %@ in conference %@ with topics %@", name, self.name, self.topics);
    return nil;
}

- (NSArray*)topicsSortedArray
{
    NSMutableArray *topicsArray = [[NSMutableArray alloc] init];
    for (Topic *topic in self.topics)
    {
        [topicsArray addObject:topic];
    }
    [topicsArray sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    return topicsArray;
}

- (Topic*)firstTopicWithInterestingMessagesAfter: (Topic*)start
{
    NSArray *topics = [self topicsSortedArray];
    NSUInteger index = [topics indexOfObject:start];
    if (index == NSNotFound)
        index = 0;
    else
        index++;
    for (; index < [topics count]; ++index)
    {
        Topic *topic = topics[index];
        if ([topic interestingMessagesCount] > 0)
            return topic;
    }
    return nil;
}

- (Topic*)firstTopicWithUnreadMessagesAfter: (Topic*)start
{
    NSArray *topics = [self topicsSortedArray];
    NSUInteger index = [topics indexOfObject:start];
    if (index == NSNotFound)
        index = 0;
    else
        index++;
    for (; index < [topics count]; ++index)
    {
        Topic *topic = topics[index];
        if ([topic messagesUnreadCount] > 0)
            return topic;
    }
    return nil;
}

- (void) markAllMessagesRead
{
    for (Topic *topic in self.topics)
        [topic markAllMessagesRead];
}
@end
