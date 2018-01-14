//
//  CIXThread.h
//  iXolr
//
//  Created by Bryan Boreham on 19/10/2013.
//
//

#import <Foundation/Foundation.h>

@class ThreadHeaderView;

// CIXThread object holds info to track thread display
@interface CIXThread : NSObject {
@public
    NSUInteger _startPosition;  // index within the view's message array
    NSUInteger _numMessages;
    NSUInteger _rootMessageNumber;  // CIX message number of the root of this thread
}

+ (id)threadWithStart: (NSUInteger) start root: (NSUInteger)root;
- (NSUInteger) countNumUnreadInMessageArray: (NSArray*)messages;
- (NSString*) titleInMessageArray: (NSArray*)messages;

@property (nonatomic, strong) ThreadHeaderView *tHeaderView;
@property (readonly) NSUInteger lastPosition;
@property (nonatomic) BOOL isExpanded;
@end

@interface NSArray (CIXThread)

- (NSArray*)findThreads;
- (NSUInteger)maxThreadLength;

@end
