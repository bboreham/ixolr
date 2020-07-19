//
//  ThreadHeaderView.m
//  iXolr
//
//  Created by Bryan Boreham on 21/04/2012.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ThreadHeaderView.h"
#import "iXolrAppDelegate.h"
#import "TableViewUtilities.h"
#import <QuartzCore/QuartzCore.h>

@implementation ThreadHeaderView

@synthesize titleLabel=_titleLabel, disclosureLabel=_disclosureLabel, delegate=_delegate, section=_section, isOpen=_isOpen;
@synthesize countsLabel=_countsLabel;
@synthesize numMessages=_numMessages, numUnreadMessages=_numUnreadMessages;

+ (Class)layerClass {
    
    return [CAGradientLayer class];
}


- (void)setupLabel: (UILabel*)label
{
    label.textColor = [self tintColor];
}

-(id)initWithFrame:(CGRect)frame title:(NSString*)title section:(NSInteger)sectionNumber open:(BOOL)open delegate:(id <ThreadHeaderViewDelegate>)delegate {
    
    self = [super initWithFrame:frame];
    
    if (self != nil) {
        // Recognize taps on this view
        UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(toggleOpen:)];
        [self addGestureRecognizer:tapGesture];
        
        // And long presses
        UIGestureRecognizer *longPressGesture = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
        [self addGestureRecognizer:longPressGesture];
        
        self.section = sectionNumber;
        _isOpen = open;
        self.delegate = delegate;        
        self.userInteractionEnabled = YES;

        CGFloat size_scale = frame.size.height / 45;
                
        // Label, with different font and colour, shows the little arrow to the left
        _disclosureLabel = [[UILabel alloc] initWithFrame: CGRectMake(1.0, size_scale * 8 - 3, size_scale * 35.0, frame.size.height - 2)];
        _disclosureLabel.text = open ? @"▼" : @"►";
        [self setupLabel:_disclosureLabel];
        [self addSubview:_disclosureLabel];
        
        // The title label.
        CGRect titleLabelFrame = self.frame;
        titleLabelFrame.origin.x += size_scale * 30;
        titleLabelFrame.size.width -= size_scale * 120;
        CGRectInset(titleLabelFrame, 3.0, size_scale * 8 - 3);
        _titleLabel = [[UILabel alloc] initWithFrame:titleLabelFrame];
        _titleLabel.text = title;
        [self setupLabel:_titleLabel];
        [self addSubview:_titleLabel];
        
        // The message counts label.
        CGRect countsLabelFrame = self.frame;
        countsLabelFrame.origin.x += countsLabelFrame.size.width - size_scale * 90;
        countsLabelFrame.size.width = size_scale * 85;
        CGRectInset(countsLabelFrame, 0.0, size_scale * 8 - 3);
        _countsLabel = [[UILabel alloc] initWithFrame:countsLabelFrame];
        _countsLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
        _countsLabel.textAlignment = NSTextAlignmentRight;
        _countsLabel.baselineAdjustment = UIBaselineAdjustmentAlignCenters;
        _countsLabel.adjustsFontSizeToFitWidth = YES;
        [self setupLabel:_countsLabel];
        [self addSubview:_countsLabel];
        
        [self setFonts];

        // Set the colors for the gradient layer.
        static NSMutableArray *colors = nil;
        if (colors == nil) {
            colors = threadHeaderGradientColors();
        }
        [(CAGradientLayer *)self.layer setColors:colors];
        [(CAGradientLayer *)self.layer setLocations:@[@0.0f, @0.95f, @1.0f]];
    }
    
    return self;
}

- (void) setFonts
{
    CGFloat size_scale = self.frame.size.height / 45;

    _disclosureLabel.font = [UIFont fontWithName: @"Arial" size: size_scale * 8 + 8];
    
    if ([iXolrAppDelegate settings].useDynamicType) {
        UIFontDescriptor *desc1 = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleSubheadline];
        UIFontDescriptor *desc = [desc1 fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
        _titleLabel.font = [UIFont fontWithDescriptor:desc size:0.0];
    } else
        _titleLabel.font = [UIFont boldSystemFontOfSize:size_scale * 8 + 10];

    _countsLabel.font = _titleLabel.font;
}

- (void) layoutSubviews
{
    // Adjust width of title so it nestles next to counts
    CGRect titleLabelFrame = _titleLabel.frame;
    titleLabelFrame.size.width = _countsLabel.frame.origin.x - titleLabelFrame.origin.x;
    _titleLabel.frame = titleLabelFrame;
}

- (void)updateCountsLabelText
{
    _countsLabel.text = [NSString stringWithFormat:@"%ld/%ld", (long)_numUnreadMessages, (long)_numMessages];
}

- (void)setNumMessages:(NSInteger)numMessages
{
    _numMessages = numMessages;
    [self updateCountsLabelText];
}

- (void)setNumUnreadMessages:(NSInteger)numUnreadMessages
{
    _numUnreadMessages = numUnreadMessages;
    [self updateCountsLabelText];
}

- (void)setNumMessages:(NSInteger)numMessages numUnread:(NSInteger)numUnreadMessages;
{
    _numMessages = numMessages;
    _numUnreadMessages = numUnreadMessages;
    [self updateCountsLabelText];
}

- (void)setIsOpen:(BOOL)isOpen {
    if (_isOpen != isOpen)
        [self toggleOpenWithUserAction:NO]; // make the callback happen
}

-(IBAction)toggleOpen:(id)sender {
    
    [self toggleOpenWithUserAction:YES];
}

-(IBAction)longPress:(UIGestureRecognizer *)recognizer {
    if (recognizer.state != UIGestureRecognizerStateBegan) 
        return;
    if ([self.delegate respondsToSelector:@selector(threadHeaderView:longPress:)]) {
        [self.delegate threadHeaderView:self longPress:self.section];
    }
}

-(void)toggleOpenWithUserAction:(BOOL)userAction {
    
    // Toggle the disclosure button state.
    _isOpen = !_isOpen;
    self.disclosureLabel.text = self.isOpen ? @"▼" : @"►";
    
    // If this was a user action, send the delegate the appropriate message.
    if (userAction) {
        if (self.isOpen) {
            if ([self.delegate respondsToSelector:@selector(threadHeaderView:sectionOpened:)]) {
                [self.delegate threadHeaderView:self sectionOpened:self.section];
            }
        }
        else {
            if ([self.delegate respondsToSelector:@selector(threadHeaderView:sectionClosed:)]) {
                [self.delegate threadHeaderView:self sectionClosed:self.section];
            }
        }
    }
}




@end
