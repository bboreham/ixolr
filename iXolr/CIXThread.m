//
//  CIXThread.m
//  iXolr
//
//  Created by Bryan Boreham on 19/10/2013.
//
//

#import "CIXThread.h"
#import "ThreadHeaderView.h"
#import "Message.h"
#import "iXolrAppDelegate.h"

@implementation CIXThread 

@synthesize tHeaderView=_theaderView;
@synthesize isExpanded=_isExpanded;

+ (id)threadWithStart: (NSUInteger) start root: (NSUInteger)root
{
    return [[CIXThread alloc] initWithStart:start root:root];
}

- (id)initWithStart: (NSUInteger) start root: (NSUInteger)root
{
    self = [super init];
    if (self) {
        _startPosition = start;
        _rootMessageNumber = root;
    }
    return self;
}


// Thread descriptors are equal if they refer to the same root message
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[self class]])
    {
        CIXThread *other = (CIXThread*)object;
        return _rootMessageNumber == other->_rootMessageNumber;
    }
    return NO;
}

- (NSUInteger)lastPosition { return _startPosition + _numMessages; }

- (void)setIsExpanded:(BOOL)isExpanded {
    _isExpanded = isExpanded;
    [_theaderView setIsOpen: isExpanded];
}

- (NSUInteger) countNumUnreadInMessageArray: (NSArray*)messages
{
    NSUInteger numUnread = 0;
    for (NSUInteger i = 0; i < self->_numMessages; ++i) {
        id<GenericMessage> message = messages[self->_startPosition+i];
        if (!message.isRead && !message.isIgnored)
            ++numUnread;
    }
    return numUnread;
}

// Return title of first non-placeholder message in thread
- (NSString*) titleInMessageArray: (NSArray*)messages
{
    NSUInteger pos = _startPosition;
    CIXMessage *message;
    do {
        message = messages[pos++];
    } while (pos < self.lastPosition && message.isPlaceholder);
    return message.firstLine;
}

@end

@implementation NSArray (CIXThread)

// Go through the messages and find each root message and set up a thread object to match
- (NSArray*)findThreads
{
    NSMutableArray *newThreadArray = [NSMutableArray arrayWithCapacity:1000];
    NSUInteger pos = 0;
    CIXThread *lastThread = nil;
    for (id<GenericMessage> message in self) {
        if (message.commentTo == 0) {    // Find all the root messages
            if (lastThread != nil) {
                lastThread->_numMessages = pos - lastThread->_startPosition;
            }
            CIXThread *thread = [[CIXThread alloc] initWithStart:pos root:[message msgnum_int]];
            [newThreadArray addObject:thread];
            lastThread = thread;
        }
        ++pos;
    }
    if (lastThread != nil)
        lastThread->_numMessages = pos - lastThread->_startPosition;    // Fix up the last one
    return newThreadArray;
}

// In this one we are passed an array of CIXThread objects
- (NSUInteger)maxThreadLength
{
    NSUInteger maxThreadLength = 0;
    for (CIXThread *thread in self) {
        if (maxThreadLength < thread->_numMessages)
            maxThreadLength = thread->_numMessages;
    }
    return maxThreadLength;
}

@end

