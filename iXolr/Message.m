//
//  CIXMessage.m
//  iXolr
//
//  Created by Bryan Boreham on 25/08/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "Message.h"
#import "Topic.h"
#import "Conference.h"
#import "NSString+HTML.h"
#import "StringUtils.h"
#import "ActivityProviders.h"

// Bitmask for values of flags property
typedef enum {
    MFnone = 0,
    MFinteresting=1,
    MFplaceholder=2,
    MFoutbox=4,
    MFfavourite=8,
    MFignored=16,
    MFheld=32,
} MessageFlagsType;


@implementation CIXMessage
@dynamic msgnum;
@dynamic author;
@dynamic date;
@dynamic commentTo;
@dynamic text;
@dynamic indent;
@dynamic flags;
@dynamic isRead;
@dynamic topic;
@synthesize indentTransient = _indentTransient;

- (int)msgnum_int
{
    return self.msgnum;
}

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

- (void) setIsOutboxMessage:(BOOL)isOutboxMessage
{
    [self setOrClearFlag:MFoutbox withBool:isOutboxMessage];
    if (isOutboxMessage) 
        // Make sure this message sorts after all real messages; also this number is magic and used to recognize outbox messages in DB queries
        self.msgnum = 999999;
}

- (BOOL)isOutboxMessage
{
    return [self testFlag:MFoutbox];
}

- (void) setIsPlaceholder:(BOOL)isPlaceholder
{
     [NSException raise:@"Invalid flag" format:@"an attempt was made to set the placeholder flag on a real message object"];
}

- (BOOL)isPlaceholder
{
    return NO;
}

- (void) setIsInteresting:(BOOL)isInteresting
{
    [self setOrClearFlag:MFinteresting withBool:isInteresting];
}

- (BOOL)isInteresting
{
    return [self testFlag:MFinteresting];
}

- (void) setIsIgnored:(BOOL)isIgnored
{
    [self setOrClearFlag:MFignored withBool:isIgnored];
}

- (BOOL)isIgnored
{
    return [self testFlag:MFignored];
}

- (void) setIsFavourite:(BOOL)isFavourite {
    [self setOrClearFlag:MFfavourite withBool:isFavourite];
}

- (BOOL)isFavourite {
    return [self testFlag:MFfavourite];
}

- (BOOL)isHeld {
    return [self testFlag:MFheld];
}

- (void) setIsHeld:(BOOL)isHeld {
    [self setOrClearFlag:MFheld withBool:isHeld];
}

- (NSString *)summary
{
    if (self.commentTo == 0)
        return [NSString stringWithFormat:@"New in %@/%@", self.topic.conference.name, self.topic.name];
    else
        return [NSString stringWithFormat:@"Re #%d in %@/%@", self.commentTo, self.topic.conference.name, self.topic.name];
}

- (NSString *)cixLink
{
    return [NSString stringWithFormat:@"cix:%@/%@:%d", self.topic.conference.name, self.topic.name, self.msgnum_int];
}

- (NSString *)description
{
    return [self cixLink];
}

- (NSString *)firstLine
{ return [self firstLineWithMaxLength:64]; }

- (NSString *)firstLineWithMaxLength: (NSInteger) MAXLINELENGTH
{
    // Return the first nonblank, nonquote line
    NSString *text = self.text;
    NSInteger pos = 0, end = 0, length = [text length], firstLineEnd = 0;
    NSCharacterSet *whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    do {
        // Find the first nonwhitespace character
        while (pos < length && [whitespace characterIsMember: [text characterAtIndex:pos]])
            ++pos;
        end = pos;
        // Find the next newline after that, or the end of the message if no newline
        while (end < length && [text characterAtIndex:end] != '\n')
            ++end;
        if (end >= length)
            break;
        if (firstLineEnd == 0)
            firstLineEnd = end;
        if ([text characterAtIndex:pos] == '>')   // If we found a quotation line, move to next line
            pos = end;
        else {
            NSRange compare_range = {pos, 9};
            if (pos + 9 < length &&
                ([text compare:@"**REPOST:" options:NSLiteralSearch range:compare_range] == NSOrderedSame ||
                [text compare:@"**COPIED " options:NSLiteralSearch range:compare_range] == NSOrderedSame))
                pos = end;  // If we found a repost line, move to next line
            else
                break;
        }
    } while (1);
    if (end == pos) {   // Somehow we ended up with a completely blank line; go back to the first line
        pos = 0; end = firstLineEnd;
    }
    if (end-pos > MAXLINELENGTH) {  // If line is too long, trim it
        end = pos + MAXLINELENGTH;
        // Step back a little to see if we can find whitespace
        while (end > pos + MAXLINELENGTH - 10 && ![whitespace characterIsMember: [text characterAtIndex:end]])
            --end;
    }
    NSRange lineRange = {pos, end - pos};
    return [self.text substringWithRange:lineRange];
}

- (NSString*) dateString
{
    return [self.date asStringWith: @"%@"];
}

- (NSString *)headerLine
{
    NSString *fmt=nil;
    if (self.isOutboxMessage)
        fmt = @"In outbox - %@";
    else
        fmt = [NSString stringWithFormat: @"#%d from %@ at %%@", self.msgnum, self.author];
    
    return [self.date asStringWith: fmt];
}

- (NSString *)textAsHTMLwithSize: (float)size reflow: (BOOL)reflow forWidth: (float)width inlineImages: (BOOL)inlineImages
{
    UIFont *font = (size == 0) ? [UIFont preferredFontForTextStyle:UIFontTextStyleBody] : [UIFont fontWithName:@"helvetica" size:size];
    if (size == 0)
        size = font.pointSize;
    NSString *headStr =
        [NSString stringWithFormat:@"<html> <head> \n"
         "<style type=\"text/css\"> "
         ":root {color-scheme: light dark; "
         "  --text-color: black; "
         "  --quote-color: blue; "
         "  --link-color: blue; "
         "} "
         "@media screen and (prefers-color-scheme: dark) { "
         "  :root { "
         "  --text-color: #AAAAAA; "
         "  --quote-color: #6666FF; "
         "  --link-color: #4488FF; "
         "  }"
         "} "
         "body {font-family: \"%@\"; font-size: %f; color: var(--text-color); } "
         ".quote { color: var(--quote-color); } "
         "a { color: var(--link-color); } "
         ".inlineimage {max-width: %.0fpx;} "
         "</style> \n"
         "</head> \n", font.familyName, size, width-10];

    if (width < 20) // unreasonably small - work round it
        width = 240;
    return [NSString stringWithFormat: @"%@<body>%@ </body></html>",
            headStr, [self.text stringByConvertingCIXMsgToHTMLwithReflow:reflow lineBreakWidth:width font:font inlineImages:inlineImages]];
}

const int CIX_MAX_LINE_LENGTH=70;

- (NSString*)textQuoted
{
    return [@"> " stringByAppendingString: [[self.text stringWithLineBreaksAt:CIX_MAX_LINE_LENGTH] stringByReplacingOccurrencesOfString:@"\n" withString:@"\n> "]];
}

// Protocol methods for UIActivityItemSource, so we can appear in 'post to Facebook' type menus
- (id)activityViewControllerPlaceholderItem:(UIActivityViewController *)activityViewController
{
    return self;
}

- (id)activityViewController:(UIActivityViewController *)activityViewController itemForActivityType:(NSString *)activityType
{
    return self;
}
@end

@implementation PlaceholderMessage
@synthesize msgnum;
@synthesize commentTo;
@synthesize isRead;
@synthesize topic;
@synthesize isFavourite;
@synthesize indentTransient = _indentTransient;

+ (id)placeholderWithTopic:(Topic*)topic msgnum:(NSInteger)msgnum
{
    NSObject <GenericMessage> *placeholder = [[PlaceholderMessage alloc] init];
    placeholder.msgnum = (int32_t)msgnum;
    placeholder.topic = topic;
    placeholder.isRead = YES;
    return placeholder;
}

// Placeholders are equal if their topic and message numbers are the same
- (BOOL)isEqual:(id)object
{
    if ([object isKindOfClass:[self class]])
    {
        PlaceholderMessage *other = (PlaceholderMessage*)object;
        return self.topic == other.topic && self.msgnum_int == other.msgnum_int;
    }
    return NO;
}

// Because we changed isEqual, we are also required to change hash.
- (NSUInteger)hash
{
    return self.msgnum_int;
}


- (BOOL)isPlaceholder
{
    return YES;
}

- (BOOL)isOutboxMessage
{
    return NO;
}

- (BOOL)isInteresting {
    return NO;
}

- (void) setIsIgnored:(BOOL)isIgnored {}    // Just ignore this
- (BOOL)isIgnored { return NO; }
- (BOOL)isHeld { return NO; }

- (NSString *)author { return nil; }
- (NSString *)text { return nil; }
- (NSDate *)date { return nil; }
- (int32_t)commentTo { return 0; }

- (NSString*) dateString
{
    return @"";
}

- (int)msgnum_int
{
    return self.msgnum;
}

- (NSString *)summary
{
    return [NSString stringWithFormat: @"Message %d not downloaded", self.msgnum];
}

- (NSString *)cixLink
{
    return [NSString stringWithFormat:@"cix:%@/%@:%d", self.topic.conference.name, self.topic.name, self.msgnum_int];
}

- (NSString *)description
{
    return [NSString stringWithFormat:@"Placeholder %@/%@:%d", self.topic.conference.name, self.topic.name, self.msgnum_int];
}

- (NSString *)firstLine
{ return [self firstLineWithMaxLength:64]; }

- (NSString *)firstLineWithMaxLength: (NSInteger) max
{
    return [self summary];
}

- (NSString *)headerLine
{
    return [self summary];
}

- (NSString *)textAsHTMLwithSize: (float)size reflow: (BOOL)reflow forWidth: (float)width inlineImages: (BOOL)inlineImages
{
    return @"<html><head><style type=\"text/css\"> :root {color-scheme: light dark;} </style></head><body> </body></html>";
}

- (NSString*)textQuoted
{
    return [NSString stringWithFormat: @"> %@", self.headerLine];
}
@end
