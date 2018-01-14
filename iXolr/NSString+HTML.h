//
//  NSString+HTML.h
//  iXolr
//
//  Created by Bryan Boreham on 14/09/2011.
//  Copyright (c) 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSString (HTML)

// Instance Methods
- (NSString *)stringWithReflow;
- (NSString *)stringWithLineBreaksAt: (NSUInteger) lineBreakWidth;
- (NSString *)stringByConvertingCIXMsgToHTMLwithReflow: (BOOL)reflow lineBreakWidth: (NSUInteger)lineBreakWidth font: (UIFont*)font inlineImages: (BOOL)inlineImages;

@end
