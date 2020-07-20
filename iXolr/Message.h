//
//  Message.h
//  iXolr
//
//  Created by Bryan Boreham on 25/08/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import <UIkit/UIActivityItemProvider.h>

@class Topic;

@protocol GenericMessage

@required
@property (nonatomic) int32_t msgnum;
-(NSString *) author;
-(NSDate *) date;
-(int32_t) commentTo;
-(NSString *) text;
@property (nonatomic) BOOL isRead;
@property (nonatomic, retain) Topic * topic;

@property (nonatomic, readonly) int msgnum_int;
@property (nonatomic) int indentTransient;
@property (nonatomic, readonly) NSString *summary;
@property (nonatomic, readonly) NSString *cixLink;
@property (nonatomic, readonly) NSString *firstLine;
- (NSString*) dateString;
- (NSString *)firstLineWithMaxLength: (NSInteger) max;
@property (nonatomic, readonly) NSString *headerLine;
- (NSString *)textAsHTMLwithSize: (float)size reflow: (BOOL)reflow forWidth: (float)width inlineImages: (BOOL)inlineImages;
@property (nonatomic, readonly) NSString *textQuoted;
@property (nonatomic, readonly) BOOL isOutboxMessage;
@property (nonatomic, readonly) BOOL isPlaceholder;
@property (nonatomic, readonly) BOOL isInteresting;
@property (nonatomic) BOOL isIgnored;
@property (nonatomic, readonly) BOOL isHeld;
@property (nonatomic) BOOL isFavourite;

@end

@interface CIXMessage : NSManagedObject <GenericMessage, UIActivityItemSource> {
@private
    int _indentTransient;
}
@property (nonatomic) int32_t msgnum;
@property (nonatomic, strong) NSString * author;
@property (nonatomic, strong) NSDate * date;
@property (nonatomic) int32_t commentTo;
@property (nonatomic, strong) NSString * text;
@property (nonatomic) int32_t indent;
@property (nonatomic) int32_t flags;
@property (nonatomic) BOOL isRead;
@property (nonatomic, strong) Topic * topic;

@property (nonatomic, readonly) int msgnum_int;
@property (nonatomic) int indentTransient;
@property (weak, nonatomic, readonly) NSString *summary;
@property (weak, nonatomic, readonly) NSString *cixLink;
@property (weak, nonatomic, readonly) NSString *firstLine;
- (NSString*) dateString;
- (NSString *)firstLineWithMaxLength: (NSInteger) max;
@property (weak, nonatomic, readonly) NSString *headerLine;
- (NSString *)textAsHTMLwithSize: (float)size reflow: (BOOL)reflow forWidth: (float)width inlineImages: (BOOL)inlineImages;
@property (weak, nonatomic, readonly) NSString *textQuoted;
@property (nonatomic) BOOL isOutboxMessage;
@property (nonatomic) BOOL isPlaceholder;
@property (nonatomic) BOOL isInteresting;
@property (nonatomic) BOOL isIgnored;
@property (nonatomic) BOOL isFavourite;
@property (nonatomic) BOOL isHeld;
@end

@interface PlaceholderMessage : NSObject <GenericMessage> {
@private
    int _indentTransient;
}
+ (id)placeholderWithTopic:(Topic*)topic msgnum:(NSInteger)msgnum;
+ (NSString *)HTMLforBlankMessage;
@property (nonatomic) int32_t msgnum;
@property (weak, nonatomic, readonly) NSString * author;
@property (weak, nonatomic, readonly) NSDate * date;
@property (nonatomic) int32_t commentTo;
@property (weak, nonatomic, readonly) NSString * text;
@property (nonatomic) BOOL isRead;
@property (nonatomic, strong) Topic * topic;

@property (nonatomic, readonly) int msgnum_int;
@property (nonatomic) int indentTransient;
@property (weak, nonatomic, readonly) NSString *summary;
@property (weak, nonatomic, readonly) NSString *firstLine;
- (NSString*) dateString;
- (NSString *)firstLineWithMaxLength: (NSInteger) max;
@property (weak, nonatomic, readonly) NSString *headerLine;
- (NSString *)textAsHTMLwithSize: (float)size reflow: (BOOL)reflow forWidth: (float)width inlineImages: (BOOL)inlineImages;
@property (weak, nonatomic, readonly) NSString *textQuoted;
@property (nonatomic, readonly) BOOL isOutboxMessage;
@property (nonatomic, readonly) BOOL isPlaceholder;
@property (nonatomic, readonly) BOOL isInteresting;
@property (nonatomic) BOOL isIgnored;
@property (nonatomic) BOOL isFavourite;
@end
