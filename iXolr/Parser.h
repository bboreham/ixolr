//
//  Parser.h
//  iXolr
//
//  Created by Bryan Boreham on 16/05/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Topic;
@class CIXMessage;
@class DataQueryHelper;

struct ParserCounts {
    NSInteger newmessages, unread, interesting;
};

@interface Parser : NSObject

- (id) initWithDataQueryHelper: (DataQueryHelper*)dc;
- (Topic *) parseTopicFromDictionary:(NSDictionary*)item;
- (CIXMessage *) parseMessageFromDictionary:(NSDictionary*)item interestingUser:(NSString*)interestingUser counts:(struct ParserCounts*)counts;
- (NSDate *) parseDate: (NSString *) datetimestr;
- (void) finish;
- (NSDictionary*)parseJSONtoDictionary:(NSData*)jsondata;
+ (NSDictionary*)parseJSONtoDictionary:(NSData*)jsondata;
+ (NSData*)JSONfromMessageLink:(NSString*)link;
+ (NSData*)JSONfromMessage:(CIXMessage*)message;
+ (NSData*)JSONfromSearchQuery:(NSString*)query;
+ (NSData*)JSONfromSearchQuery:(NSString*)query confName:(NSString*)confName author:(NSString*)author years:(NSInteger)years;
+ (NSData*)JSONfromMessageNumbers:(NSArray*)messages conf:(NSString*)conf topic:(NSString*)topic;
+ (NSData*)JSONRangesfromMessageLinks:(NSArray*) messages;
+ (NSArray*) messageSortDescriptors;

@end
