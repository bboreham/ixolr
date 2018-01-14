//
//  ThreadedMessageListVC.h
//  iXolr
//
//  Created by Bryan Boreham on 04/02/2014.
//
//

#import <UIKit/UIKit.h>
#import "ThreadHeaderView.h"

@class Topic;
@class CIXMessage;
@protocol GenericMessage;
@protocol ThreadedMessageListDelegate;

@interface ThreadedMessageListVC : NSObject<UITableViewDataSource, UITableViewDelegate, ThreadHeaderViewDelegate>

- (void)handleChangedMessagesInTopic:(Topic*)topic;
- (void)handleMessageReadCountChanged:(id<GenericMessage>)message;
- (void)redrawAllVisibleRows;
- (void)userTextSizeDidChange;
- (void)configureThreadsWithReload:(BOOL)reload;
- (void)configureView:(Topic*)topic withReload:(BOOL)reload;
- (void) encodeRestorableStateWithCoder:(NSCoder *)coder;
- (void) decodeRestorableStateWithCoder:(NSCoder *)coder;
- (void)forceRedrawOfMessage: (id<GenericMessage>)message;
- (void)markSubthreadPriority:(CIXMessage*)message status: (BOOL)value;
- (void)markSubthreadIgnored:(NSObject<GenericMessage>*)message status: (BOOL)value;
- (id)addPlaceholder:(NSInteger) msgnum topic:(Topic*)topic;
- (void)moveToDisplayMessage:(NSObject<GenericMessage>*)message topicNew:(BOOL)isTopicNew animated:(BOOL)animated;
- (NSObject<GenericMessage>*) firstUnread;
- (NSObject<GenericMessage>*) nextUnread;
- (NSObject<GenericMessage>*) firstInteresting;
- (NSObject<GenericMessage>*) nextInteresting;
- (NSObject<GenericMessage>*) messageWithNumber: (NSInteger) msgnum;
- (NSObject<GenericMessage>*) nextRow;
- (NSObject<GenericMessage>*) prevRow;
- (NSObject<GenericMessage>*) nextThreadRoot;
- (NSObject<GenericMessage>*) prevThreadRoot;
- (NSObject<GenericMessage>*) nextMessageMatching:(NSString*) text;

@property (nonatomic, strong) IBOutlet UITableView *messageTableView;
@property (nonatomic, weak) id <ThreadedMessageListDelegate> delegate;   // Note we do not retain the delegate to avoid cycles.

@end

/*
 Protocol to be adopted by the delegate.
 */
@protocol ThreadedMessageListDelegate <NSObject>

@optional
-(NSObject<GenericMessage>*)currentMessage;
-(void)threadedMessageList:(ThreadedMessageListVC*)threadHeaderView messageSelected:(NSObject<GenericMessage>*)message;

@end
