//
//  StringUtils.m
//  iXolr
//
//  Created by Bryan Boreham on 03/04/2015.
//
//

#import "StringUtils.h"

@implementation NSString (NSInteger)
+ (NSString*) fromNSInteger: (NSInteger)i
{
    return [NSString stringWithFormat:@"%ld", (long)i];
}

+ (NSString*) fromNSUInteger: (NSUInteger)i
{
    return [NSString stringWithFormat:@"%lu", (unsigned long)i];
}
@end

@implementation NSDate (shortFormat)
- (NSString*) asStringWith:(NSString*)fmt {
    NSString *dateStr = nil;
    // Drop the date if the date is within the last six hours
    if ([self timeIntervalSinceNow] > -6*3600)
        dateStr = [NSDateFormatter localizedStringFromDate:self dateStyle:NSDateFormatterNoStyle timeStyle:NSDateFormatterShortStyle];
    // Drop the year if the date is within the last six months
    else if ([self timeIntervalSinceNow] > -182*24*3600)
    {
        static NSDateFormatter *formatter = nil;
        if (formatter == nil) {
            formatter = [[NSDateFormatter alloc] init];
            [formatter setDateFormat:@"dd MMM HH:mm"];
        }
        dateStr = [formatter stringFromDate:self];
    } else
        dateStr = [NSDateFormatter localizedStringFromDate:self dateStyle:NSDateFormatterMediumStyle timeStyle:NSDateFormatterShortStyle];
    return [NSString stringWithFormat:fmt, dateStr];
}
@end


@implementation NSData (utf8string)

- (NSString *)asUTF8String {
    return [[NSString alloc] initWithData:self encoding:NSUTF8StringEncoding];
}
@end

