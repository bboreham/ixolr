//
//  NSString+HTML.h
//  iXolr
//
//  Created by Bryan Boreham on 14/09/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import "NSString+HTML.h"

enum text_state {
    state_begin,
    state_quotebegin,
    state_text,
};

@interface StringReformatter : NSObject {
    @private
    NSCharacterSet *whitespace, *letters, *breakReflowChars ;
    NSMutableCharacterSet *wsAndPunct, *urlchars ;
    NSUInteger length;
    unichar *inbuf;
    NSMutableString *result ;   // The string we are building to output
    NSMutableString *result_clean; // Same text as result, but without markup
    unichar pc, c, nc; // previous character, current char, next char
    bool in_bold, in_italic, in_underline;
    NSUInteger pos, column, result_column;
    NSUInteger quote_count, prev_quote_count;
    enum text_state state;
    @public
    BOOL htmlOutput, reflow_nonQuotes, lineBreak_Quotes, lineBreak_nonQuotes, inlineImages;
    NSUInteger lineBreakWidth, lineBreakColumn;
    UIFont *font;
}
@end

@implementation StringReformatter

static const NSUInteger LINE_BREAK_WIDTH = 50;

- (id)initWithSize: (NSUInteger) size {
    self = [super init];
    lineBreakColumn = LINE_BREAK_WIDTH;
    whitespace = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    wsAndPunct = [NSMutableCharacterSet whitespaceAndNewlineCharacterSet];
    [wsAndPunct addCharactersInString:@"()[]<>"];
    letters    = [NSCharacterSet letterCharacterSet];
    urlchars = [NSMutableCharacterSet alphanumericCharacterSet];
    [urlchars addCharactersInString:@":/._%-+&?="];
    breakReflowChars = [NSCharacterSet characterSetWithCharactersInString:@"*. \t\n"];
    
	result = [[NSMutableString alloc] initWithCapacity:size];
	result_clean = [[NSMutableString alloc] initWithCapacity:size];
    return self;
}

- (void)reset {
    pc=' '; 
    in_bold = in_italic = in_underline = false;
    quote_count = prev_quote_count = 0;
    state = state_begin;
    column = 1;
    result_column = 0;
    free(inbuf);
    inbuf = nil;
    [result setString:@""];
    [result_clean setString:@""];
}

- (void)dealloc {
    free(inbuf);
}

- (void)appendChar: (unichar) ch
{
    if (htmlOutput)
        switch (ch) {
            case '<':
                [result appendString:@"&lt;"];
                break;
                
            case '>':
                [result appendString:@"&gt;"];
                break;
                
            case '&':
                [result appendString:@"&amp;"];
                break;
                
            default:
                [result appendFormat:@"%C", ch];
        }
    else
        [result appendFormat:@"%C", ch];
    [result_clean appendFormat:@"%C", ch];
    ++result_column;
}

// Given a starting emphasis character emph, check if there is a closing one.  So *bold* is ok but /var/cache is not
- (BOOL) lineContainsEmphasisChar: (unichar) emph startingAt: (NSUInteger) start
{
    for (; start < length; ++start)
    {
        unichar ch = inbuf[start];
        if (ch == emph && (start+1 >= length || ![letters characterIsMember:inbuf[start+1]]))
            return YES;
        else if (ch == '\n')
            break;
    }    
    return NO;
}

- (void)insertQuoteHeaderAtIndex: (NSUInteger)index
{
    result_column = quote_count * 2 + ([result length] - index);
    for (NSUInteger i = 0; i < quote_count; ++i)
        [result insertString:htmlOutput ? @"&gt; " : @"> " atIndex:index];
    if (htmlOutput && quote_count > 0)
        [result insertString:@"<span class=quote>" atIndex:index];
    for (NSUInteger i = 0; i < quote_count; ++i)
        [result_clean insertString:@"> " atIndex:0];
}

- (void)checkBeforeOutputText
{
    // See if this is a quote line at a different quoting level than the previous line
    if ((state == state_quotebegin || state == state_begin) && result_column > 0 && prev_quote_count != quote_count) {
        [self lineBreak];
    }
    if (result_column == 0) 
        [self insertQuoteHeaderAtIndex:[result length]];
    state = state_text;
}

- (void)handleMarkup: (bool*)flag HTMLchar: (unichar) html
{
    [self checkBeforeOutputText];
    if (htmlOutput && *flag && ![letters characterIsMember:nc]) // Check if we are ending an emphasis section e.g. *bold*
    {
        [result appendFormat: @"</%C>", html];
        *flag = false;
    }
    // Check if we are beginning an emphasis section
    else if (htmlOutput && !*flag && [whitespace characterIsMember:pc] && [letters characterIsMember:nc] && [self lineContainsEmphasisChar:c startingAt:pos+1])
    {
        [result appendFormat: @"<%C>", html];
        *flag = true;
    }
    else
        [self appendChar: c];
}

-(void)lineBreak
{
    if (htmlOutput) {
        if (prev_quote_count > 0)
            [result appendString:@"</span>"];
        [result appendString:@"<br>\n"];
    } else {
        [result appendString:@"\n"];
    }
    result_column = 0;
    [result_clean setString:@""];
}

// Figure out the rendered width of the string from the last linebreak, excluding markup.
- (NSUInteger)widthOfLineTo: (NSUInteger)end
{
    NSUInteger skip = [result length]-end;
    NSString *lineSubstring = [result_clean substringToIndex:[result_clean length]-skip];
    CGSize size = [lineSubstring sizeWithFont:font];
    return size.width;
}

- (void)regularCharHandling
{
    [self checkBeforeOutputText];
    [self appendChar:c];

    // See if the line is one we want to break here
    if (((quote_count > 0 && lineBreak_Quotes) || lineBreak_nonQuotes) && result_column >= lineBreakColumn) {
        // Step back a little to see if we can find whitespace
        NSUInteger end = [result length] - 1;
        if (font == nil || [self widthOfLineTo:end+1] > lineBreakWidth) { // Check we really do have to break the line here
            while (end > [result length] - 30) {
                if ([whitespace characterIsMember: [result characterAtIndex:end]]) {
                    if (font == nil || lineBreakWidth == 0 || [self widthOfLineTo:end] < lineBreakWidth)
                        break;
                }
                --end;
            }
            end++;
            [result_clean setString:[result_clean substringFromIndex:[result_clean length] - ([result length]-end)]];
            [self insertQuoteHeaderAtIndex:end];
            [result insertString:htmlOutput ? @"<br>\n" : @"\n" atIndex:end];
            if (htmlOutput && quote_count > 0)
                [result insertString:@"</span>" atIndex:end];
        }
    }
}

// Convert message text to HTML, escaping >, & etc., *bold*, _underline_ and links
- (NSString *)convertCIXMsg: (NSString*)msg 
{
	// Create our own autorelease pool
	@autoreleasepool {
        [self reset];
        length = [msg length];
        inbuf = malloc(length * sizeof(unichar));
        [msg getCharacters:inbuf];
        
        for (pos = 0; pos < length; ++pos, ++column)
        {
            c = inbuf[pos];
            nc = (pos+1 < length) ? inbuf[pos+1] : ' ';
            switch (c) {
                case '>':
                    if (state == state_begin)
                        state = state_quotebegin;
                    if (state == state_quotebegin)
                        ++quote_count;
                    else 
                        [self appendChar:c];
                    break;
                    
                case '*':
                    [self handleMarkup:&in_bold HTMLchar:'b'];
                    break;
                    
                case '/':
                    [self handleMarkup:&in_italic HTMLchar:'i'];
                    break;
                    
                case '_':
                    [self handleMarkup:&in_underline HTMLchar:'u'];
                    break;
                    
                case '\n':
                    prev_quote_count = quote_count;
                    if (!reflow_nonQuotes && !lineBreak_nonQuotes && quote_count == 0)
                        [self lineBreak];   // If reflow is turned off, then break on newline, unless it's a quote
                    else if (!lineBreak_Quotes && quote_count > 0)
                        [self lineBreak];   // If this is a quote, and we /don't/ have quote reflow turned on
                    else if (column < LINE_BREAK_WIDTH) 
                        [self lineBreak];    // Short line; just break here
                    else {    // Look at first character on the next line - if '.' or '*' assume user did some formatting with and break the line here
                        if ([breakReflowChars characterIsMember: nc]) 
                            [self lineBreak];   
                        else // Not going to break the line here: add a space if the prev char was non-space
                            if (pc != ' ') 
                                [self appendChar:' '];   
                    }
                    column = 0;
                    quote_count = 0;
                    state = state_begin;
                    break;

                case 'C':
                case 'c':   // Look for a cix: link
                    if (htmlOutput && [wsAndPunct characterIsMember:pc] && nc == 'i' && pos+4 < length && inbuf[pos+2] == 'x' && inbuf[pos+3] == ':')
                    {
                        NSInteger i=4;
                        while (pos+i < length && [urlchars characterIsMember:inbuf[pos+i]])
                            ++i;
                        if (inbuf[pos+i-1] == '.') // Trailing full stop doesn't make sense as part of a url
                            --i;
                        NSRange range = {pos, i};
                        NSString *url = [msg substringWithRange:range];
                        [result appendFormat:@"<a href='%@'>%@</a>", url, url];
                        result_column += [url length];
                        pos += i-1;
                    }
                    else
                        [self regularCharHandling];
                    break;
                    
                case 'h':   // Look for a https: link and embed images
                    if (htmlOutput && inlineImages && ([wsAndPunct characterIsMember:pc] && nc == 't' && pos+9 < length &&
                                                       inbuf[pos+2] == 't' && inbuf[pos+3] == 'p' && inbuf[pos+4] == 's' && inbuf[pos+5] == ':'))
                    {
                        NSInteger i=6;
                        while (pos+i < length && [urlchars characterIsMember:inbuf[pos+i]])
                            ++i;
                        if (inbuf[pos+i-1] == '.') // Trailing full stop doesn't make sense as part of a url
                            --i;
                        NSRange range = {pos, i};
                        NSString *url = [msg substringWithRange:range];
                        NSString *ext = [[url substringFromIndex:url.length-4] lowercaseString];
                        if ([ext isEqualToString:@".png"] || [ext isEqualToString:@".jpg"] || [ext isEqualToString:@".gif"])
                            [result appendFormat:@"<a href='%@'><img class='inlineimage' src='%@'/></a>", url, url];
                        else
                            [result appendString:url];
                        pos += i-1;
                    }
                    else
                        [self regularCharHandling];
                    break;
                    
                case ' ':
                    if (state != state_quotebegin) {
                        state = state_text;
                        [self appendChar:c];
                    }
                    break;
                    
                default:
                    [self regularCharHandling];
                    break;
            }
            pc = c;
        }
	}
	
    return result;
}

@end

@implementation NSString (HTML)

#pragma mark -
#pragma mark Instance Methods

// Convert message text to HTML, escaping >, & etc., *bold*, _underline_ and links
- (NSString *)stringByConvertingCIXMsgToHTMLwithReflow: (BOOL)reflow lineBreakWidth: (NSUInteger)lineBreakWidth font: (UIFont*)font inlineImages: (BOOL)inlineImages
{
    StringReformatter *sr = [[StringReformatter alloc] initWithSize:[self length]];
    sr->htmlOutput = YES;
    sr->reflow_nonQuotes = reflow;
    sr->inlineImages = inlineImages;
    sr->lineBreak_Quotes = reflow;
    sr->lineBreakWidth = lineBreakWidth;
    sr->lineBreakColumn = lineBreakWidth / font.xHeight;     // Heuristic to get close to correct breaking column
    sr->font = font;
    NSString *result = [sr convertCIXMsg:self];

	return result;
}

- (NSString *)stringWithReflow
{
    StringReformatter *sr = [[StringReformatter alloc] initWithSize:[self length]];
    sr->htmlOutput = NO;
    sr->reflow_nonQuotes = YES;
    NSString *result = [sr convertCIXMsg:self];
    
	return result;
}

- (NSString *)stringWithLineBreaksAt: (NSUInteger) lineBreakColumn
{
    StringReformatter *sr = [[StringReformatter alloc] initWithSize:[self length]];
    sr->htmlOutput = NO;
    sr->lineBreak_Quotes = YES;
    sr->lineBreak_nonQuotes = YES;
    sr->lineBreakColumn = lineBreakColumn;
    sr->font = nil;
    NSString *result = [sr convertCIXMsg:self];
    
	return result;
}

@end
