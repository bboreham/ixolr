//
//  ThreadedMessageListVC.m
//  iXolr
//
//  Created by Bryan Boreham on 04/02/2014.
//
//

#import "ThreadedMessageListVC.h"
#import "iXolrAppDelegate.h"
#import "Topic.h"
#import "Conference.h"
#import "Message.h"
#import "TopSettingsVC.h"
#import "DataController.h"
#import "TableViewUtilities.h"
#import "CIXThread.h"
#import "ThreadHeaderView.h"

@implementation ThreadedMessageListVC
{
@private
	NSArray *messageArray;
    NSArray *threadArray;
    UITableView *_messageTableView;
    NSObject<ThreadedMessageListDelegate>* __weak _delegate;
    int threadIndentAdjustment;   // Added to message indent level to bring messages more into the middle of the display
    NSInteger threadIndentWidth;
    BOOL threadIndentPending;   // YES if we have indented too far off the right or left and have scheduled a call to re-compute
    BOOL threadIndentNeeded;    // YES if things have moved around and we need to re-compute thread indent
    BOOL _threadHeadersVisibleInThisTopic;
}

@synthesize messageTableView = _messageTableView;
@synthesize delegate = _delegate;


- (void)setMessageTableView:(UITableView *)messageTableView
{
    if (_messageTableView != messageTableView) {
        _messageTableView = messageTableView;
        _messageTableView.dataSource = self;
        _messageTableView.delegate = self;
        [self resetMessageTableHeights];
    }
}

#pragma mark - Thread and Message utils

- (NSUInteger)messageIndexForIndexPath:(NSIndexPath *)indexPath
{
    CIXThread *thread = threadArray[indexPath.section];
    return thread->_startPosition + indexPath.row;
}

- (CIXMessage *)messageForIndexPath:(NSIndexPath *)indexPath {
    return messageArray[[self messageIndexForIndexPath:indexPath]];
}

- (CIXThread*) threadForRootMessageNumber: (int) rootMessageNumber
{
    for (CIXThread *thread in threadArray)
        if (thread->_rootMessageNumber == rootMessageNumber)
            return thread;
    return nil;
}

- (CIXThread*) threadForMessage: (id<GenericMessage>) message
{
    NSInteger index = [messageArray indexOfObject:message];
    for (CIXThread *thread in threadArray) {
        if (index >= thread->_startPosition && index < (thread->_startPosition + thread->_numMessages))
            return thread;
    }
    return nil;
}

- (NSIndexPath*)indexPathForMessage: (id<GenericMessage>) message
{
    NSInteger index = [messageArray indexOfObject:message];
    NSInteger threadIndex = 0;
    for (CIXThread *thread in threadArray) {
        if (index >= thread->_startPosition && index < (thread->_startPosition + thread->_numMessages))
            return [NSIndexPath indexPathForRow:(index - thread->_startPosition) inSection:threadIndex];
        ++threadIndex;
    }
    return nil;
}

- (NSObject<GenericMessage>*) messageWithNumber: (NSInteger) msgnum
{
    for (NSObject<GenericMessage>* msg in messageArray)
        if (msg.msgnum_int == msgnum)
            return msg;
    return nil;
}

#pragma mark - Font

- (UIFont*) messageListFontForMessage: (id<GenericMessage>)message {
    BOOL useDynamicType = [iXolrAppDelegate settings].useDynamicType;
    CGFloat textSize = [iXolrAppDelegate iPad] ? 15.0 : 13.0;
    BOOL isRootMessage = !_threadHeadersVisibleInThisTopic && (message.commentTo == 0 && !message.isPlaceholder);
    if (isRootMessage)
        if (useDynamicType) {
            UIFontDescriptor *desc1 = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
            UIFontDescriptor *desc = [desc1 fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
            return [UIFont fontWithDescriptor:desc size:0.0];
        } else
            return [UIFont fontWithName: @"Helvetica-Bold" size:textSize];
        else
            if (useDynamicType)
                return [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
            else
                return [UIFont fontWithName: @"Helvetica" size:textSize];
}

- (NSUInteger) maxLineLengthForList {
    UIFont *font = [self messageListFontForMessage:nil];
    NSUInteger x = self.messageTableView.frame.size.width / font.xHeight * 3/4;
    if (x < 20) // something went wrong
        return 20;
    else
        return x - 2;
}

- (CGFloat)messageTableRowHeight
{
    UIFont *font = [self messageListFontForMessage:nil];
    return floorf( font.lineHeight * 1.5f );
}

- (void)userTextSizeDidChange
{
    for (CIXThread *thread in threadArray)
        thread.tHeaderView = nil;      // Clear these out so they will be re-created at the right size.
    [self resetMessageTableHeights];
    [self.messageTableView reloadData];
}

#pragma mark - Managing topic and message in view

- (void)forceRedrawOfPath: (NSIndexPath *)path
{
    [self configureCell:[self.messageTableView cellForRowAtIndexPath:path] atIndexPath:path];
}

- (void)forceRedrawOfMessage: (id<GenericMessage>)message
{
    NSIndexPath *path = [self indexPathForMessage:message];
    [self forceRedrawOfPath:path];
}

// Notification has arrived of new messages in one topic; see if anything needs to be added to the thread view
- (void)handleChangedMessagesInTopic:(Topic*)topic
{
        NSArray *newMessages = [topic messagesThreaded];
        NSMutableArray *rowsAdded=[NSMutableArray array], *rowsDeleted=[NSMutableArray array];
        
        // Figure out which threads have been added and removed, and create IndexSets for those
        NSMutableArray *threadsAdded=nil, *threadsDeleted=nil;
        NSArray *newThreadsFound = [newMessages findThreads];
        [threadArray computeDifferenceTo:newThreadsFound returningAdded:&threadsAdded andDeleted:&threadsDeleted inSection:0];
        NSMutableIndexSet *sectionsAdded = [NSMutableIndexSet indexSet], *sectionsDeleted = [NSMutableIndexSet indexSet];
        for (NSIndexPath *path in threadsDeleted)
            [sectionsDeleted addIndex:path.row];
        for (NSIndexPath *path in threadsAdded)
            [sectionsAdded addIndex:path.row];
        
        // Walk the two thread arrays indexed by oldIndex and newIndex, skipping deleted and added threads
        // Example: a, b, c, d, e -> a, c, p, d, e : b removed and p added. 0,0 1,1 2,1 3,3 4,4 5,5
        for (NSUInteger oldIndex = 0, newIndex = 0; oldIndex < [threadArray count]; ++oldIndex) {
            bool oldSectionDeleted = [sectionsDeleted containsIndex:oldIndex];
            while (!oldSectionDeleted && [sectionsAdded containsIndex:newIndex])
                ++newIndex;
            if (!oldSectionDeleted || (oldSectionDeleted && [sectionsAdded containsIndex:newIndex])) {
                // If this thread has been both deleted and added then this means it has a different root message due to backloading
                CIXThread *oldThread = threadArray[oldIndex];
                CIXThread *newThread = newThreadsFound[newIndex];
                if (oldThread.isExpanded) {
                    newThread.isExpanded = YES;
                    NSRange oldRange = {oldThread->_startPosition, oldThread->_numMessages};
                    NSArray *oldThreadMessages = [messageArray subarrayWithRange:oldRange];
                    NSRange newRange = {newThread->_startPosition, newThread->_numMessages};
                    NSArray *newThreadMessages = [newMessages subarrayWithRange:newRange];
                    NSMutableArray *threadRowsAdded=nil, *threadRowsDeleted=nil;
                    [oldThreadMessages computeDifferenceTo:newThreadMessages returningAdded:&threadRowsAdded andDeleted:&threadRowsDeleted inSection:newIndex];
                    [rowsAdded addObjectsFromArray:threadRowsAdded];
                    for (NSIndexPath *path in threadRowsDeleted)    // add these one at a time, overwriting newIndex section number that computeDifference put in with oldIndex.
                        [rowsDeleted addObject: [NSIndexPath indexPathForRow:path.row inSection:oldIndex]];
                }
                newThread.tHeaderView = oldThread.tHeaderView;
                newThread.tHeaderView.section = newIndex;
                newThread.tHeaderView.titleLabel.text = [newThread titleInMessageArray:newMessages];
                [newThread.tHeaderView setNumMessages:newThread->_numMessages numUnread: [newThread countNumUnreadInMessageArray:newMessages]];
                ++newIndex;
            }
        }
        threadArray = newThreadsFound;
        messageArray = newMessages;
        if (![iXolrAppDelegate settings].animationsOn)
            [self.messageTableView reloadData];
        else {
            [CATransaction begin];
            [self.messageTableView beginUpdates];
            [self.messageTableView insertSections:sectionsAdded withRowAnimation:UITableViewRowAnimationTop];
            [self.messageTableView deleteSections:sectionsDeleted withRowAnimation:UITableViewRowAnimationTop];
            [self.messageTableView insertRowsAtIndexPaths:rowsAdded withRowAnimation:UITableViewRowAnimationTop];
            [self.messageTableView deleteRowsAtIndexPaths:rowsDeleted withRowAnimation:UITableViewRowAnimationFade];
            [self.messageTableView endUpdates];
            [CATransaction commit];
        }
}

// The read count in a topic has changed for a single object
- (void)handleMessageReadCountChanged:(id<GenericMessage>)message
{
    CIXThread *thread = [self threadForMessage: message];
    if (!message.isIgnored)
        thread.tHeaderView.numUnreadMessages = thread.tHeaderView.numUnreadMessages + (message.isRead ? -1 : 1);
    [self forceRedrawOfMessage:message];    // Force redraw to show read status
}


- (void)redrawAllVisibleRows
{
    NSArray *visiblePaths = [self.messageTableView indexPathsForVisibleRows];
    for (NSIndexPath *path in visiblePaths)
        [self forceRedrawOfPath:path];
    for (CIXThread *thread in threadArray)
        thread.tHeaderView.numUnreadMessages = [thread countNumUnreadInMessageArray:messageArray];
}

- (void)configureThreadsWithReload:(BOOL)reload
{
    threadArray = [messageArray findThreads];
    NSUInteger maxThreadLength = [threadArray maxThreadLength];
    // If every thread is of length 1 then no point decorating with headers
    _threadHeadersVisibleInThisTopic = [iXolrAppDelegate settings].threadHeadersVisible && !(maxThreadLength == 1);
    if ([iXolrAppDelegate settings].threadsDefaultOpen || !_threadHeadersVisibleInThisTopic)
        for (CIXThread *thread in threadArray)
            [thread setIsExpanded:YES];
    
    self.messageTableView.sectionHeaderHeight = _threadHeadersVisibleInThisTopic ? self.messageTableView.rowHeight : 0;
    if (reload)
        [self.messageTableView reloadData];
}

- (void)configureView:(Topic*)topic withReload:(BOOL)reload
{
    messageArray = [topic messagesThreaded];
    
    threadIndentWidth = [iXolrAppDelegate iPad] ? 12 : 10;
    threadIndentAdjustment = 0;
    threadIndentNeeded = YES;
    
    [self configureThreadsWithReload:reload];
}

- (void)resetMessageTableHeights
{
    self.messageTableView.rowHeight = [self messageTableRowHeight];
    self.messageTableView.sectionHeaderHeight = _threadHeadersVisibleInThisTopic ? self.messageTableView.rowHeight : 0;
}

#pragma mark - Message and Thread flags

- (void)markThreadRead:(CIXThread*)thread status: (BOOL)value
{
    NSUInteger section = [threadArray indexOfObject:thread];
    id<GenericMessage> message = nil;
    for (NSUInteger i = 0; i < thread->_numMessages; ++i) {
        message = messageArray[thread->_startPosition+i];
        if (message.isRead == !value)
        {
            message.isRead = value;
            if (thread.isExpanded)     // Force redraw to show read status
                [self forceRedrawOfPath: [NSIndexPath indexPathForRow:i inSection:section]];
        }
    }
    [message.topic messageMultipleReadStatusChanged];
    thread.tHeaderView.numUnreadMessages = value ? 0 : thread->_numMessages;
}

// Mark message and all messages that are comments to it, or comments to those, etc.
- (void)invoke:(NSInvocation*)invocation onSubthreadStartingAt:(NSObject<GenericMessage>*)message
{
    [invocation invokeWithTarget:message];
    [self forceRedrawOfMessage:message];
    // Now set all messages in sub-thread, which is every message after this one until we hit a root message or a comment to an earlier message
    NSInteger start_msgnum = message.msgnum_int;
    NSUInteger index = [messageArray indexOfObject:message] + 1;
    for (; index < [messageArray count]; ++index) {
        message = messageArray[index];
        if (message.isPlaceholder || message.commentTo < start_msgnum)
            break;
        [invocation invokeWithTarget:message];
        [self forceRedrawOfMessage:message];
    }
    [[iXolrAppDelegate singleton].dataController saveContext];
}

- (void)markSubthreadPriority:(CIXMessage*)message status: (BOOL)value
{
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[message methodSignatureForSelector:@selector(setIsInteresting:)]];
    [inv setSelector:@selector(setIsInteresting:)];
    [inv setArgument:&value atIndex:2];
    [self invoke:inv onSubthreadStartingAt:message];
    [message.topic messageMultipleReadStatusChanged];  // Not really the read status that changed, but this will force a recount anyway
}

- (void)markSubthreadIgnored:(NSObject<GenericMessage>*)message status: (BOOL)value
{
    NSInvocation *inv = [NSInvocation invocationWithMethodSignature:[message methodSignatureForSelector:@selector(setIsIgnored:)]];
    [inv setSelector:@selector(setIsIgnored:)];
    [inv setArgument:&value atIndex:2];
    [self invoke:inv onSubthreadStartingAt:message];
    CIXThread *thread = [self threadForMessage:message];
    thread.tHeaderView.numUnreadMessages = [thread countNumUnreadInMessageArray:messageArray];
    [message.topic messageMultipleReadStatusChanged];
}

// Add a temporary placeholder, e.g. because we have been asked to go to a nonexistent message.  This method is a cut-down version of handleChangedMessages
- (id)addPlaceholder:(NSInteger) msgnum topic:(Topic*)topic
{
    NSObject <GenericMessage> *placeholder = [PlaceholderMessage placeholderWithTopic:topic msgnum:msgnum];
    // Insert a placeholder and thread for this message, after everything else so it doesn't screw up the numbering of other threads
    NSArray *newMessages = [messageArray arrayByAddingObject:placeholder];
    messageArray = newMessages;
    CIXThread *thread = [CIXThread threadWithStart:[newMessages count]-1 root:msgnum];
    thread->_numMessages = 1;
    NSArray *newThreads = [threadArray arrayByAddingObject:thread];
    threadArray = newThreads;
    [self.messageTableView insertSections:[NSIndexSet indexSetWithIndex:[newThreads count]-1] withRowAnimation:UITableViewRowAnimationTop];
    return placeholder;
}

// encode open/closed state of all threads
- (void) encodeRestorableStateWithCoder:(NSCoder *)coder {
    NSMutableArray *openThreads = [NSMutableArray arrayWithCapacity:20];
    for (CIXThread *thread in threadArray)
        if (thread.isExpanded)
            [openThreads addObject:@(thread->_rootMessageNumber)];
    if (openThreads.count > 0)
        [coder encodeObject:openThreads forKey:@"tableOpenThreads"];
}

- (void) decodeRestorableStateWithCoder:(NSCoder *)coder {
    NSArray *openThreads = [coder decodeObjectForKey:@"tableOpenThreads"];
    if (openThreads != nil) {
        for (NSNumber *num in openThreads)
            [self threadForRootMessageNumber: num.intValue].isExpanded = YES;
        [self.messageTableView reloadData];
    }
}

#pragma mark - Moving around

- (NSArray*)visiblePathsCentredOn:(NSIndexPath*)path
{
    CIXThread *thread = threadArray[path.section];
    int numRowsVisible = [self numRowsVisibleInMessageTableView];
    NSMutableArray *paths = [NSMutableArray arrayWithCapacity:numRowsVisible+1];
    for (int i = -(numRowsVisible / 2); i <= (numRowsVisible / 2); ++i)
        if (path.row+i >= 0 && path.row+i < thread->_numMessages)
            [paths addObject:[NSIndexPath indexPathForRow:path.row+i inSection:path.section]];
    return paths;
}

- (int)numRowsVisibleInMessageTableView
{
    return (int)ceil(self.messageTableView.frame.size.height / self.messageTableView.rowHeight);
}

// Move to show a particular message
- (void)moveToDisplayMessage:(NSObject<GenericMessage>*)message topicNew:(BOOL)isTopicNew animated:(BOOL)animated
{
    if (self.messageTableView == nil)
        return;
    NSIndexPath *oldFirstVisiblePath = nil;
    if (!isTopicNew) {
        NSArray *visiblePaths = [self.messageTableView indexPathsForVisibleRows];
        if ([visiblePaths count] > 0) {
            oldFirstVisiblePath = visiblePaths[0];
        }
    }
    NSIndexPath *path = [self indexPathForMessage:message];
    if (path != nil && messageArray != nil) {
        CIXThread *thread = threadArray[path.section];
        if (!thread.isExpanded) {
            thread.isExpanded = YES;
            if (animated)
                [self.messageTableView reloadSection:path.section];
            else
                [self.messageTableView reloadData];
            CGSize size = self.messageTableView.contentSize;
            size.height += self.messageTableView.rowHeight * thread->_numMessages;
            self.messageTableView.contentSize = size;
        }
        // If we're scrolling a lot of rows up or down, recompute the indentation
        NSInteger numRowsVisible = [self numRowsVisibleInMessageTableView];
        if (threadIndentNeeded || oldFirstVisiblePath.section != path.section || labs(path.row - oldFirstVisiblePath.row) > numRowsVisible)
        {
            NSArray *paths = [self visiblePathsCentredOn:path];
            int indentDelta = [self computeThreadIndentForIndexPaths:paths];
            if (indentDelta != 0) {
                NSArray *pathsToAdjust = [paths intersect:[self.messageTableView indexPathsForVisibleRows]];
                [self adjustThreadIndentForPaths:pathsToAdjust byDelta:indentDelta];
            }
        }
        else if (message.indentTransient + threadIndentAdjustment < 0)  // Make sure at least this one message is visible
            [self adjustThreadIndent];
        [self.messageTableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
        [CATransaction begin];
        [self.messageTableView scrollToRowAtIndexPath:path atScrollPosition:UITableViewScrollPositionMiddle animated:animated];
        [CATransaction commit];
    }
}

- (NSInteger) currentRowNumber
{
    NSIndexPath *currentSelection = [self.messageTableView indexPathForSelectedRow];
    if (currentSelection != nil)
        return [self messageIndexForIndexPath:currentSelection];
    else
        return -1;
}

- (NSObject<GenericMessage>*) nextUnreadAfterRow: (NSInteger) currentRow
{
    CIXMessage *firstUnread = nil;
    for (; currentRow < [messageArray count]; ++currentRow)
    {
        CIXMessage *message = messageArray[currentRow];
        if (message.isRead == NO && !message.isIgnored) {
            firstUnread = message;
            break;
        }
    }
    return firstUnread;
}

- (NSObject<GenericMessage>*) firstUnread
{
    return [self nextUnreadAfterRow: 0];
}

- (NSObject<GenericMessage>*) nextUnread
{
    return [self nextUnreadAfterRow: [self currentRowNumber] + 1 ];
}

// Look for an 'interesting' message, which we would prefer to read ahead of others
- (NSObject<GenericMessage>*) firstInteresting {
    return [self nextInterestingAfterRow: 0];
}

- (NSObject<GenericMessage>*) nextInteresting {
    return [self nextInterestingAfterRow: [self currentRowNumber] + 1];
}

- (NSObject<GenericMessage>*) nextInterestingAfterRow:(NSInteger)currentRow
{
    for (; currentRow < [messageArray count]; ++currentRow)
    {
        CIXMessage *message = messageArray[currentRow];
        if (message.isRead == NO && !message.isIgnored && message.isInteresting)
            return message;
    }
    return nil;
}

- (NSObject<GenericMessage>*) nextRow
{
    NSInteger currentRow = [self currentRowNumber];
    if (currentRow >= 0 && currentRow+1 < messageArray.count)
        return messageArray[currentRow+1];
    else
        return nil;
}

- (NSObject<GenericMessage>*) prevRow
{
    NSInteger currentRow = [self currentRowNumber];
    if (currentRow > 0)
        return messageArray[currentRow-1];
    else
        return nil;
}

- (NSObject<GenericMessage>*) prevThreadRoot
{
    NSInteger currentRow = [self currentRowNumber];
    if (currentRow > 0)
    {
        id<GenericMessage> message = messageArray[currentRow];
        CIXThread *thread = [self threadForMessage:message];
        if (thread != nil) {
            if (thread->_rootMessageNumber == message.msgnum)   // at the root already; find previous root
            {
                NSInteger threadPos = [threadArray indexOfObject:thread];
                if (threadPos > 0)
                    thread = threadArray[threadPos-1];
                else
                    thread = nil;
            }
        }
        if (thread != nil)
            return [self messageWithNumber: thread->_rootMessageNumber];
    }
    return nil;
}

- (NSObject<GenericMessage>*) nextThreadRoot
{
    NSInteger currentRow = [self currentRowNumber];
    if (currentRow >= 0)
    {
        id<GenericMessage> message = messageArray[currentRow];
        CIXThread *thread = [self threadForMessage:message];
        if (thread != nil) {
            NSInteger threadPos = [threadArray indexOfObject:thread];
            if (threadPos+1 < [threadArray count]) {
                thread = threadArray[threadPos+1];
                return [self messageWithNumber: thread->_rootMessageNumber];
            }
        }
    }
    return nil;
}

// Find next message matching search text in this topic
- (NSObject<GenericMessage>*) nextMessageMatching:(NSString*) text
{
    NSInteger currentRow = [self currentRowNumber] + 1;
    for (; currentRow < [messageArray count]; ++currentRow)
    {
        CIXMessage *message = messageArray[currentRow];
        if (message.isPlaceholder)
            continue;
        NSRange range = [message.text rangeOfString:text options:NSCaseInsensitiveSearch];
        NSRange nrange = [message.author rangeOfString:text options:NSCaseInsensitiveSearch];
        if (range.location != NSNotFound || nrange.location != NSNotFound)
            return message;
    }
    return nil;
}

#pragma mark - Indenting

#define INDENT_MIN 0

// Compute the distance that the given rows should move left or right in order to optimise visibility
- (int) computeThreadIndentForIndexPaths:(NSArray*)paths
{
    /*if (paths.count > 0) {
     NSIndexPath *first = paths[0], *last = paths[paths.count-1];
     NSLog(@"computeThreadIndentForIndexPaths: %d/%d to %d/%d", first.section, first.row, last.section, last.row);
     }*/
    
    NSObject<GenericMessage> *currentMessage = [self.delegate currentMessage];
    const int INDENT_MAX = self.messageTableView.frame.size.width / threadIndentWidth / 3 - 2;
    BOOL currentMessageIncluded = NO;
    int minIndent = 9999, maxIndent = -9999;
    for (NSIndexPath *path in paths) {
        CIXMessage *message = [self messageForIndexPath:path];
        int thisIndent = message.indentTransient + threadIndentAdjustment;
        if (minIndent > thisIndent)
            minIndent = thisIndent;
        if (maxIndent < thisIndent)
            maxIndent = thisIndent;
        if (message == currentMessage)
            currentMessageIncluded = YES;
    }
    int indentDelta = 0;
    if (minIndent < INDENT_MIN) {    // If lines are off to the left, move right
        indentDelta = -minIndent + (INDENT_MAX / 4);
        if (indentDelta > -threadIndentAdjustment)  // Don't move further right than the margin
            indentDelta = -threadIndentAdjustment;
    }
    if (maxIndent > INDENT_MAX) {        // Now if lines are too far right, move left
        indentDelta = -(maxIndent - INDENT_MAX + (INDENT_MAX / 4));
        if (indentDelta < -minIndent)
            indentDelta = -minIndent;
    }
    // Don't move current message further too far left or right
    if (currentMessageIncluded) {
        int currentMessageIndent = threadIndentAdjustment + currentMessage.indentTransient;
        if (currentMessageIndent + indentDelta > INDENT_MAX)
            indentDelta = INDENT_MAX - currentMessageIndent;
        else if (currentMessageIndent + indentDelta < INDENT_MIN)
            indentDelta = INDENT_MIN - currentMessageIndent;
    }
    
    threadIndentAdjustment += indentDelta;
    //NSLog(@"min = %d, max = %d: MAX %d indent %d delta %d, width %d", minIndent, maxIndent, INDENT_MAX, threadIndentAdjustment, indentDelta, threadIndentWidth);
    threadIndentNeeded = NO;
    return indentDelta;
}

// Move all visible rows in the threaded view left or right
- (void) adjustThreadIndent
{
    NSArray *visiblePaths = [self.messageTableView indexPathsForVisibleRows];
    NSInteger indentDelta = [self computeThreadIndentForIndexPaths: visiblePaths];
    //NSLog(@"adjustThreadIndent: threadIndentAdjustment: %d indentDelta %d", threadIndentAdjustment, indentDelta);
    [self adjustThreadIndentForPaths:visiblePaths byDelta:indentDelta];
}

- (void)adjustThreadIndentForPaths: (NSArray*)paths byDelta: (NSInteger)indentDelta
{
    /*if (paths.count > 0) {
     NSIndexPath *first = paths[0], *last = paths[paths.count-1];
     NSLog(@"adjustThreadIndentForPaths for paths %d/%d to %d/%d by delta %d", first.section, first.row, last.section, last.row, indentDelta);
     }*/
    if (indentDelta != 0 && paths.count > 0)
    {
        NSTimeInterval duration = [iXolrAppDelegate settings].animationsOn ? 0.5f : 0.0f;
        [CATransaction begin];
        for (NSIndexPath *path in paths) {
            UITableViewCell *cell = [self.messageTableView cellForRowAtIndexPath:path];
            CGRect frame = cell.textLabel.frame;
            frame.origin.x += ((cell.indentationLevel+indentDelta)*threadIndentWidth - cell.indentationLevel*cell.indentationWidth);
            [UIView animateWithDuration:duration animations:^{
                cell.textLabel.frame = frame;
            }];
        }
        // We need to set the indentationLevel on each cell so that table redrawing (e.g. to move the highlight) works properly
        // But, if we do it before the animation then each cell redraws immediately
        [CATransaction setCompletionBlock:^(void){
            for (NSIndexPath *path in paths) {
                UITableViewCell *cell = [self.messageTableView cellForRowAtIndexPath:path];
                cell.indentationWidth = threadIndentWidth;
                //NSLog(@"(completion) setting cell %p path %d/%d indent to %d", cell, path.section, path.row, cell.indentationLevel + indentDelta);
                cell.indentationLevel = cell.indentationLevel + indentDelta;
            }
        } ];
        [CATransaction commit];
    }
    threadIndentPending = NO;
}

#pragma mark - Table delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [threadArray count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    CIXThread *thread = threadArray[section];
    return thread.isExpanded ? thread->_numMessages : 0;
}

-(UIView*)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
    if (!_threadHeadersVisibleInThisTopic)
        return nil;
    
    CIXThread *thread = threadArray[section];
    if (!thread.tHeaderView) {   // create on demand
        CGFloat headerHeight = self.messageTableView.sectionHeaderHeight;
        ThreadHeaderView *hv = [[ThreadHeaderView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.messageTableView.bounds.size.width, headerHeight) title:[thread titleInMessageArray:messageArray] section:section open:thread.isExpanded delegate:self];
        [hv setNumMessages:thread->_numMessages numUnread: [thread countNumUnreadInMessageArray:messageArray]];
        thread.tHeaderView = hv;
           // CIXthread object owns it now
    }
    
    return thread.tHeaderView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
	static NSString *CellIdentifier = @"MessageCellIdentifier";
	
	// Dequeue or create a cell of the appropriate type.
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:CellIdentifier];
        cell.indentationWidth = threadIndentWidth;
    }
    
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    if (cell == nil)
        return;
    const NSInteger INDENT_MAX_POINTS = self.messageTableView.frame.size.width / 3;
    id<GenericMessage> message = [self messageForIndexPath:indexPath];
    UIFont *font = [self messageListFontForMessage: message];
    const NSInteger MAXLINELENGTH = [self maxLineLengthForList];
    
    //NSLog(@"configureCell %p AtIndexPath: %d/%d msg %d indentT %d adj %d", cell, indexPath.section, indexPath.row, message.msgnum_int, message.indentTransient, threadIndentAdjustment);
    
    NSInteger indent = message.indentTransient + threadIndentAdjustment;
    if (!threadIndentPending && (indent < INDENT_MIN || indent * threadIndentWidth > INDENT_MAX_POINTS)) {
        threadIndentNeeded = YES;
        threadIndentPending = YES;
        [self performSelector:@selector(adjustThreadIndent) withObject:nil afterDelay:0.5];
    }
    cell.textLabel.text = [message firstLineWithMaxLength: MAXLINELENGTH];
    cell.indentationLevel = indent;
    cell.detailTextLabel.text = message.isOutboxMessage ? @"[Outbox]" : message.author;
    
    UIColor *textColor = basicTextColor();
    UIColor *detailColor = authorColor();
    if (message.isInteresting || message.isOutboxMessage)
        textColor = priorityColor();
    if (message.isIgnored) {
        textColor = [textColor colorWithAlphaComponent:0.3];
        detailColor = textColor;
    } else if (message.isRead == YES)
        textColor = [textColor colorWithAlphaComponent:0.6];
    cell.textLabel.textColor = textColor;
    cell.textLabel.font = font;
    cell.detailTextLabel.font = font;
    cell.detailTextLabel.textColor = detailColor;
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return NO;
}

// User has selected one message from the list
- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    CIXMessage *message = [self messageForIndexPath:indexPath];
    [self.delegate threadedMessageList:self messageSelected:message];
    const NSInteger INDENT_MAX = self.messageTableView.frame.size.width / threadIndentWidth / 3 - 2;
    if (message.indentTransient + threadIndentAdjustment < 0 || message.indentTransient + threadIndentAdjustment > INDENT_MAX)  // Make sure at least this one message is visible
        [self adjustThreadIndent];
}

#pragma mark - ThreadHeaderView

// make the first row in the section visible
-(void)makeVisible:(ThreadHeaderView*)threadHeaderView
{
    CGRect rectToMakeVisible = threadHeaderView.frame;
    rectToMakeVisible.size.height *= 2;
    [self.messageTableView scrollRectToVisible:rectToMakeVisible animated:YES];;
}

// Callback when user touches header row to open up a thread
-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView sectionOpened:(NSInteger)section {
	if (section > threadArray.count)
        return;     // Something wrong - got a callback on a thread header that shouldn't exist
    
    CIXThread *thread = threadArray[section];
	thread.isExpanded = YES;
    [self.messageTableView reloadSection:section];
    // If this thread is right at the bottom of the frame, try to make the first row in the section visible.
    if (threadHeaderView.center.y + threadHeaderView.frame.size.height - self.messageTableView.contentOffset.y > self.messageTableView.frame.size.height)
        [self performSelector:@selector(makeVisible:) withObject:threadHeaderView afterDelay:0.1];
    // Mark the currently-selected row as such, if it is in the section we just opened
    if (self.delegate.currentMessage != nil) {
        NSIndexPath *currentMessagePath = [self indexPathForMessage: self.delegate.currentMessage];
        if (currentMessagePath.section == section)
            [self.messageTableView selectRowAtIndexPath:currentMessagePath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }
}

-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView sectionClosed:(NSInteger)section {
	if (section > threadArray.count)
        return;     // Something wrong - got a callback on a thread header that shouldn't exist
	
    CIXThread *thread = threadArray[section];
	thread.isExpanded = NO;
    [self.messageTableView reloadSection:section];
}

-(void)threadHeaderView:(ThreadHeaderView*)threadHeaderView longPress:(NSInteger)section {
	if (section > threadArray.count)
        return;     // Something wrong - got a callback on a thread header that shouldn't exist
    
    CIXThread *thread = threadArray[section];
    CIXMessage *rootMsg = messageArray[thread->_startPosition];
    NSString *threadTitle = [thread titleInMessageArray:messageArray];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Thread Actions"
        message:[NSString stringWithFormat:@"Which action do you want to perform on this thread?"]
        completionBlock:^(NSUInteger buttonIndex) {
            if (buttonIndex > 0) {
                NSString *messageStr = nil;
                if (buttonIndex == 1)
                    messageStr = [NSString stringWithFormat:@"Do you want to mark all messages in thread '%@' as read?", threadTitle];
                else if (buttonIndex == 2)
                    messageStr = [NSString stringWithFormat:@"Do you want to mark all messages in thread '%@' as unread?", threadTitle];
                else if (buttonIndex == 3) {
                    if (rootMsg.isIgnored)
                        messageStr = [NSString stringWithFormat:@"Clear the ignored flag on thread '%@'?", threadTitle];
                    else
                        messageStr = [NSString stringWithFormat:@"Mark thread '%@' as ignored?", threadTitle];
                }
                UIAlertView *alert2 = [[UIAlertView alloc] initWithTitle:@"Confirm" message:messageStr completionBlock:^(NSUInteger button2Index) {
                    if (button2Index == 1) {
                        if (buttonIndex == 1)
                            [self markThreadRead:thread status:YES];
                        else if (buttonIndex == 2)
                            [self markThreadRead:thread status:NO];
                        else if (buttonIndex == 3)
                            [self markSubthreadIgnored:rootMsg status:!rootMsg.isIgnored];
                    }
                }
                    cancelButtonTitle:@"Cancel" otherButtonTitles:@"Confirm", nil];
                [alert2 show];
            }
        }
      cancelButtonTitle:@"Cancel" otherButtonTitles:@"Mark All Read", @"Mark All Unread", rootMsg.isIgnored ? @"Clear Ignored" : @"Mark Thread Ignored", nil];
    
    [alert show];
}

@end
