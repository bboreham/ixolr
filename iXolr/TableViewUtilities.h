//
//  TableViewUtilities.h
//  iXolr
//
//  Created by Bryan Boreham on 12/10/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import <Foundation/Foundation.h>

// Given two arrays that are expected to have items added or removed but not re-ordered, compute the differences
// in a way usable for UITable insertRows and deleteRows
@interface NSArray (ArrayDifference)
- (void) computeDifferenceTo:(NSArray *)newArray returningAdded:(NSMutableArray **)rowsAdded andDeleted:(NSMutableArray **)rowsDeleted inSection:(NSInteger)section;
- (NSArray *) intersect:(NSArray *)newArray;
- (NSArray*) filterOutZeroUnread;
- (NSArray*) filterOutZeroUnreadExcept: (id)leave;
@end

// Make a label briefly glow
@interface UILabel (glow)
- (void)pulseGlow;
@end

@interface UIView (shadow)
- (void)setupShadow;
@end

// Helper methods for the left-hand view; designed to be called on the toolbarItems method of a UIView
@interface NSArray (ViewToolbar)
- (UILabel*) statusLabel;
- (void)updateToolbar;
- (void) setImageOnSquishButton: (UIBarButtonItem*)squishButton;
- (void) startSpinner;
- (void) stopSpinner;
@end

// Helpers for table view
@interface UITableView (iXolrHelpers)
- (void) reloadSection:(NSInteger)section;
- (void) updateWithAdded:(NSArray *)rowsAdded andDeleted:(NSArray *)rowsDeleted inSection:(NSInteger)section;
@end

@interface UITableViewController(iXolrHelpers)
- (void) addSwitchToCell:(UITableViewCell*) cell selector:(SEL)selector value:(BOOL)value;
- (void) addSliderToCell:(UITableViewCell*) cell selector:(SEL)selector value:(float)value min:(float)min max:(float)max;
- (void) addStepperToCell:(UITableViewCell*) cell selector:(SEL)selector value:(double)value min:(double)min max:(double)max;
- (void) insertOrDeletePath: (NSIndexPath*)path flag:(BOOL)on;
@end

// UIAlertView using blocks, from http://www.wannabegeek.com/?p=96
@interface UIAlertView (BlockExtensions) <UIAlertViewDelegate>

+ (void)showWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(NSUInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;
- (id)initWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(NSUInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;
@end

@interface UIActionSheet (BlockExtensions) <UIActionSheetDelegate>

- (id)initWithTitle:(NSString *)title completionBlock:(void (^)(NSInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ...;
- (id)initWithDate:(NSDate*)date title:(NSString *)title mode:(UIDatePickerMode)mode goBlock:(void (^)(NSDate* date))goBlock cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles;
- (void)setCompletionBlock:(void (^)(NSInteger buttonIndex))block;
@end

@interface UIAlertController (BlockExtensions)
+ (id)alertControllerWithDate:(NSDate*)date title:(NSString *)title mode:(UIDatePickerMode)mode goBlock:(void (^)(NSDate* date))goBlock cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle;
@end

@interface UIDatePickerPopover : UIPopoverController <UIPopoverControllerDelegate>
{
    @private
    UIDatePicker *_datePicker;
}
- (id)initWithDate:(NSDate*)date mode:(UIDatePickerMode)mode goBlock:(void (^)(NSDate* date))goBlock goButtonTitle:(NSString *)goButtonTitle;

@end
