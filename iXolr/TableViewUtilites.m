//
//  TableViewUtilities.m
//  iXolr
//
//  Created by Bryan Boreham on 12/10/2011.
//  Copyright 2011-2018 Bryan Boreham. All rights reserved.
//

#import "TableViewUtilities.h"
#import "StringUtils.h"
#import "Conference.h"
#import <objc/runtime.h>

@implementation NSArray (ArrayDifference)

// Given two arrays that are expected have items added or removed but not re-ordered, compute the differences
// in a way usable for UITable insertRows and deleteRows
- (void) computeDifferenceTo:(NSArray *)newArray returningAdded:(NSMutableArray **)rowsAdded andDeleted:(NSMutableArray **)rowsDeleted inSection:(NSInteger)section
{
    NSArray *oldArray = self;
    *rowsAdded = [[NSMutableArray alloc] init];
    *rowsDeleted = [[NSMutableArray alloc] init];
    
    NSUInteger oldCount = [oldArray count];
    NSUInteger newCount = [newArray count];
    // Step through the two arrays
    NSInteger oldIndex = 0, newIndex=0;
    for (; newIndex < newCount && oldIndex < oldCount; )
    {
        id newItem = newArray[newIndex];
        id oldItem = oldArray[oldIndex];
        // If the two objects match, we step forward on both sides
        if (newItem == oldItem || [newItem isEqual:oldItem]) {
            ++newIndex;
            ++oldIndex;
        }
        else {
            // Look for the old item to appear later in the new array, which would mean we have to add the rows in between
            NSRange range = { newIndex+1, newCount - newIndex-1 };
            NSUInteger foundIndex = [newArray indexOfObject:oldItem inRange:range];
            if (foundIndex != NSNotFound)
                for (; newIndex < foundIndex; ++newIndex)
                    [*rowsAdded addObject:[NSIndexPath indexPathForRow:newIndex inSection:section]];
            else {
                // Look for the new item to appear later in the old array, which would mean we have to remove the rows in between
                NSRange range = { oldIndex+1, oldCount - oldIndex-1 };
                NSUInteger foundIndex = [oldArray indexOfObject:newItem inRange:range];
                if (foundIndex != NSNotFound)
                    for (; oldIndex < foundIndex; ++oldIndex)
                        [*rowsDeleted addObject:[NSIndexPath indexPathForRow:oldIndex inSection:section]];
                else {
                    // Old item must be removed and new item added, then we carry on
                    [*rowsAdded addObject:[NSIndexPath indexPathForRow:newIndex++ inSection:section]];
                    [*rowsDeleted addObject:[NSIndexPath indexPathForRow:oldIndex++ inSection:section]];
                }
            }
        }
    }
    // Once the loop is finished, add in what's left in the new array and remove what is left in the old array
    for (; newIndex < newCount; ++newIndex)
        [*rowsAdded addObject:[NSIndexPath indexPathForRow:newIndex inSection:section]];
    for (; oldIndex < oldCount; ++oldIndex)
        [*rowsDeleted addObject:[NSIndexPath indexPathForRow:oldIndex inSection:section]];
}

// Given two arrays that are expected have items added or removed but not re-ordered, compute the intersection
- (NSArray *) intersect:(NSArray *)newArray
{
    NSArray *oldArray = self;
    NSMutableArray *returnArray = [NSMutableArray arrayWithCapacity:self.count];
    
    NSUInteger oldCount = [oldArray count];
    NSUInteger newCount = [newArray count];
    // Step through the two arrays
    NSInteger oldIndex = 0, newIndex=0;
    for (; newIndex < newCount && oldIndex < oldCount; )
    {
        id newItem = newArray[newIndex];
        id oldItem = oldArray[oldIndex];
        // If the two objects match, we step forward on both sides
        if (newItem == oldItem || [newItem isEqual:oldItem]) {
            [returnArray addObject:newItem];
            ++newIndex;
            ++oldIndex;
        }
        else {
            // Look for the old item to appear later in the new array
            NSRange range = { newIndex+1, newCount - newIndex-1 };
            NSUInteger foundIndex = [newArray indexOfObject:oldItem inRange:range];
            if (foundIndex != NSNotFound)
                newIndex = foundIndex;
            else {
                // Look for the new item to appear later in the old array
                NSRange range = { oldIndex+1, oldCount - oldIndex-1 };
                NSUInteger foundIndex = [oldArray indexOfObject:newItem inRange:range];
                if (foundIndex != NSNotFound)
                    oldIndex = foundIndex;
                else
                    break;  // No more matches
            }
        }
    }
    return returnArray;
}

- (NSArray*) filterOutZeroUnread
{
    return [self filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary * bindings) 
             {return [evaluatedObject messagesUnreadCount] > 0;}]];
}

- (NSArray*) filterOutZeroUnreadExcept: (id)leave
{
    return [self filteredArrayUsingPredicate:
            [NSPredicate predicateWithBlock:^BOOL(id evaluatedObject, NSDictionary * bindings) 
             {return [evaluatedObject messagesUnreadCount] > 0 || evaluatedObject == leave;}]];
}
@end

#import <QuartzCore/CAAnimation.h>

// Make a label briefly glow
@implementation UILabel (glow)
- (void)pulseGlow
{
    static CAAnimationGroup *glow = nil;
    if (glow == nil)
    {
        glow = [[CAAnimationGroup alloc] init];
        CABasicAnimation* radiusAnimation = [CABasicAnimation animationWithKeyPath:@"shadowRadius"];
        radiusAnimation.fromValue = @0.0f;
        radiusAnimation.toValue = @10.0f;
        radiusAnimation.autoreverses = YES;
        radiusAnimation.duration = 0.2;
        CABasicAnimation* opacityAnimation = [CABasicAnimation animationWithKeyPath:@"shadowOpacity"];
        opacityAnimation.fromValue = @0.0f;
        opacityAnimation.toValue = @1.0f;
        opacityAnimation.autoreverses = YES;
        opacityAnimation.duration = 0.2;
        glow.animations = @[radiusAnimation, opacityAnimation];
        glow.duration = 0.4;
    }
    
    [self setBackgroundColor:[UIColor clearColor]];
    //self.layer.shadowColor = [[UIColor yellowColor] CGColor];
    self.layer.shadowOffset = CGSizeMake(0.0, 0.0);
    self.layer.masksToBounds = NO;
    
    [self.layer addAnimation:glow forKey:@"glowAnimation"];    
}
@end

#import "iXolrAppDelegate.h"

// Magic numbers embedded in xib file
#define LAST_REFRESHED_TAG 123
#define REFRESH_ACTIVITY 321

// These methods are designed to be called on the toolbarItems method of a UIView
@implementation NSArray (ViewToolbar)
- (UILabel*) statusLabel
{
    UIBarButtonItem *lastRefreshedItem = self[2];
    return (UILabel*)[lastRefreshedItem.customView viewWithTag:LAST_REFRESHED_TAG];
}

- (void)setImageOnSquishButton: (UIBarButtonItem*)squishButton
{
    if ([iXolrAppDelegate settings].squishRows)
        squishButton.image = [UIImage imageNamed:@"squishOut.png"];
    else
        squishButton.image = [UIImage imageNamed:@"squish.png"];
}

- (void)updateToolbar
{
    UILabel *label = [self statusLabel];
    NSDate *lastRefreshed = [iXolrAppDelegate singleton].lastRefreshed;
    if (lastRefreshed == nil) {
        label.text = @"";
    } else {
        label.text = [lastRefreshed asStringWith:@"Last refreshed: %@"];
    }
}

- (void) startSpinner
{
    UIBarButtonItem *lastRefreshedItem = self[2];
    UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView *)[lastRefreshedItem.customView viewWithTag:REFRESH_ACTIVITY];
    activityIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
    [activityIndicator startAnimating];
}

- (void) stopSpinner
{
    UIBarButtonItem *lastRefreshedItem = self[2];
    UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView *)[lastRefreshedItem.customView viewWithTag:REFRESH_ACTIVITY];
    [activityIndicator stopAnimating];
}
@end

@implementation UITableView (iXolrHelpers)
- (void) reloadSection:(NSInteger)section
{
    if (![iXolrAppDelegate settings].animationsOn)
        [self reloadData];
    else
        [self reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationNone];
}

- (void) updateWithAdded:(NSArray *)rowsAdded andDeleted:(NSArray *)rowsDeleted inSection:(NSInteger)section
{
    // If the entire section appeared or disappeared (rows went from 0 to N or N to 0), reload the whole section so the section header is re-fetched
    NSUInteger numRowsNow = [self.dataSource tableView:self numberOfRowsInSection:section];
    if (![iXolrAppDelegate settings].animationsOn)
        [self reloadData];
    else if (numRowsNow == 0 || numRowsNow == [rowsAdded count] || rowsAdded == nil)
        [self reloadSections:[NSIndexSet indexSetWithIndex:section] withRowAnimation:UITableViewRowAnimationBottom];
    else {
        [self beginUpdates];
        [self insertRowsAtIndexPaths:rowsAdded withRowAnimation:UITableViewRowAnimationBottom];
        [self deleteRowsAtIndexPaths:rowsDeleted withRowAnimation:UITableViewRowAnimationBottom];
        [self endUpdates];
    }
}
@end

@implementation UITableViewController(iXolrHelpers)

- (void) addSwitchToCell:(UITableViewCell*) cell selector:(SEL)selector value:(BOOL)value
{
    cell.detailTextLabel.text = @"";
    UISwitch *uiswitch = [[UISwitch alloc] initWithFrame: CGRectMake(0, 0, 79, 27)];
    uiswitch.on = value;
    [uiswitch addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = uiswitch;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void) addSliderToCell:(UITableViewCell*) cell selector:(SEL)selector value:(float)value min:(float)min max:(float)max
{
    cell.detailTextLabel.text = @"";
    UISlider *uislider = [[UISlider alloc] initWithFrame: CGRectMake(0, 0, [iXolrAppDelegate iPad] ? 180 : 95, 27)];
    uislider.minimumValue = min;
    uislider.maximumValue = max;
    uislider.value = value;
    [uislider addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = uislider;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void) addStepperToCell:(UITableViewCell*) cell selector:(SEL)selector value:(double)value min:(double)min max:(double)max
{
    cell.detailTextLabel.text = @"";
    UIStepper *stepper = [[UIStepper alloc] initWithFrame: CGRectMake(0, 0, 79, 27)];
    stepper.value = value;
    stepper.minimumValue = min;
    stepper.maximumValue = max;
    [stepper addTarget:self action:selector forControlEvents:UIControlEventValueChanged];
    cell.accessoryView = stepper;
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void) insertOrDeletePath: (NSIndexPath*)path flag:(BOOL)on
{
    NSArray *change = @[path];
    if (on)
        [self.tableView insertRowsAtIndexPaths:change withRowAnimation:UITableViewRowAnimationTop];
    else
        [self.tableView deleteRowsAtIndexPaths:change withRowAnimation:UITableViewRowAnimationTop];
}
@end


@implementation UIAlertView (BlockExtensions)

+ (void)showWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(NSUInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:nil cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
    alert.delegate = alert;
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString*)) {
        [alert addButtonWithTitle:arg];
    }
    va_end(args);
    objc_setAssociatedObject(alert, "blockCallback", [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [alert show];
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message completionBlock:(void (^)(NSUInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    self = [self initWithTitle:title message:message delegate:self cancelButtonTitle:cancelButtonTitle otherButtonTitles:nil];
    va_list args;
    va_start(args, otherButtonTitles);
    for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString*)) {  
        [self addButtonWithTitle:arg];  
    }
    va_end(args);
    objc_setAssociatedObject(self, "blockCallback", [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return self;
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    void (^block)(NSUInteger buttonIndex) = objc_getAssociatedObject(self, "blockCallback");
    block(buttonIndex);
    objc_setAssociatedObject(self, "blockCallback", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIActionSheet (BlockExtensions)

- (id)initWithTitle:(NSString *)title completionBlock:(void (^)(NSInteger buttonIndex))block cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle otherButtonTitles:(NSString *)otherButtonTitles, ... {
    self = [self initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:destructiveButtonTitle otherButtonTitles:nil, nil];
    va_list args;
    va_start(args, otherButtonTitles);
    int i = 0;
    for (NSString *arg = otherButtonTitles; arg != nil; arg = va_arg(args, NSString*), ++i) {  
        [self addButtonWithTitle:arg];
    }
    va_end(args);
    if (cancelButtonTitle != nil)
        self.cancelButtonIndex = [self addButtonWithTitle:cancelButtonTitle];
    if (block != nil)
        [self setCompletionBlock:block];
    return self;
}

- (void)setCompletionBlock:(void (^)(NSInteger buttonIndex))block
{
    objc_setAssociatedObject(self, "blockCallback", [block copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    void (^block)(NSUInteger buttonIndex) = objc_getAssociatedObject(self, "blockCallback");
    if (block == nil)
        return; // don't understand why this is getting called twice.
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        block(buttonIndex);
    }];
    objc_setAssociatedObject(self, "blockCallback", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

@end

@implementation UIAlertController (BlockExtensions)
+ (id)alertControllerWithDate:(NSDate*)date title:(NSString *)title mode:(UIDatePickerMode)mode goBlock:(void (^)(NSDate* date))goBlock cancelButtonTitle:(NSString *)cancelButtonTitle destructiveButtonTitle:(NSString *)destructiveButtonTitle {
    NSString *spacer = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? @"\n\n\n\n\n\n\n\n" : @"\n\n\n\n\n\n\n\n\n\n";
    float xpos = UIDeviceOrientationIsLandscape([UIDevice currentDevice].orientation) ? -130 : -10;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:spacer preferredStyle:UIAlertControllerStyleActionSheet];
    
    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(xpos, 30, 320, 220)];
    datePicker.datePickerMode = mode;
    datePicker.date = date;

    if (destructiveButtonTitle != nil)
        [alert addAction: [UIAlertAction actionWithTitle: destructiveButtonTitle
                               style: UIAlertActionStyleDestructive handler:^(UIAlertAction * action)
           {
               goBlock(datePicker.date);
               [alert dismissViewControllerAnimated:YES completion:nil];
               
           }]];
    if (cancelButtonTitle != nil)
        [alert addAction: [UIAlertAction actionWithTitle: cancelButtonTitle style: UIAlertActionStyleCancel handler:nil]];
    [alert.view addSubview:datePicker];
    return alert;
}
@end

@implementation UIDatePickerPopover

- (id)initWithDate:(NSDate*)date mode:(UIDatePickerMode)mode goBlock:(void (^)(NSDate* date))goBlock goButtonTitle:(NSString *)goButtonTitle {
    //build our custom popover view
    UIViewController* popoverContent = [[UIViewController alloc] init];
    UIView* popoverView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
    
    UIDatePicker *datePicker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 0, 320, 220)];
    datePicker.datePickerMode = mode;
    datePicker.date = date;
    [popoverView addSubview:datePicker];
    
    if (goButtonTitle != nil) {
        UIButton *goButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
        goButton.frame = CGRectMake(3, 222, 314, 37);
        [goButton setTitle:goButtonTitle forState:UIControlStateNormal];
        [goButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
        [goButton setBackgroundImage:[UIImage imageNamed:@"button_red"] forState:UIControlStateNormal];
        [goButton addTarget:self action:@selector(go:) forControlEvents:UIControlEventTouchUpInside];
        [popoverView addSubview:goButton];
    }

    popoverContent.view = popoverView;
    
    //resize the popover view show in the current view to the view's size
    popoverContent.preferredContentSize = CGSizeMake(320, 262);
    
    self = [self initWithContentViewController:popoverContent];
    self.delegate = self;
    _datePicker = datePicker;
    objc_setAssociatedObject(self, "blockCallback", [goBlock copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    
    return self;
}

- (IBAction)go:(id)sender
{
    void (^block)(NSDate *date) = objc_getAssociatedObject(self, "blockCallback");
    block(_datePicker.date);
    objc_setAssociatedObject(self, "blockCallback", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self dismissPopoverAnimated:YES];
     // because we did a retain when setting ourselves as the delegate
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController
{
}


@end

// Category to allow multiple buttons to be set on left and right button bar item
@interface UINavigationItem(MultipleButtonsAddition)
@property (nonatomic, strong) IBOutletCollection(UIBarButtonItem) NSArray* rightBarButtonItemsCollection;
@property (nonatomic, strong) IBOutletCollection(UIBarButtonItem) NSArray* leftBarButtonItemsCollection;
@end

@implementation UINavigationItem(MultipleButtonsAddition)

- (void) setRightBarButtonItemsCollection:(NSArray *)rightBarButtonItemsCollection {
    self.rightBarButtonItems = [rightBarButtonItemsCollection sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"tag" ascending:YES]]];
}

- (void) setLeftBarButtonItemsCollection:(NSArray *)leftBarButtonItemsCollection {
    self.leftBarButtonItems = [leftBarButtonItemsCollection sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"tag" ascending:YES]]];
}

- (NSArray*) rightBarButtonItemsCollection {
    return self.rightBarButtonItems;
}

- (NSArray*) leftBarButtonItemsCollection {
    return self.leftBarButtonItems;
}

@end

#pragma mark Color helper functions

UIColor* basicTextColor() {
    if (@available(iOS 13.0, *)) {
        return [UIColor labelColor];
    } else {
        return [UIColor blackColor];
    }
}

UIColor* grayTextColor() {
    if (@available(iOS 13.0, *)) {
        return [UIColor tertiaryLabelColor];
    } else {
        return [UIColor grayColor];
    }
}

UIColor* authorColor() {
    if (@available(iOS 11.0, *)) {
        return [UIColor colorNamed:@"messageAuthorColor"];
    } else {
        return [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1];
    }
}

UIColor* priorityColor() {
    if (@available(iOS 11.0, *)) {
        return [UIColor colorNamed:@"priorityMessageHeaderColor"];
    } else {
        return [UIColor purpleColor];
    }
}

NSMutableArray *threadHeaderGradientColors() {
    NSMutableArray *colors = [[NSMutableArray alloc] initWithCapacity:3];
    if (@available(iOS 11.0, *)) {
        [colors addObject:(id)[[UIColor colorNamed:@"threadHeaderColor1"] CGColor]];
        [colors addObject:(id)[[UIColor colorNamed:@"threadHeaderColor2"] CGColor]];
        [colors addObject:(id)[[UIColor colorNamed:@"threadHeaderColor3"] CGColor]];
    } else {
        [colors addObject:(id)[[UIColor colorWithRed:0.91 green:0.91 blue:1.00 alpha:1.0] CGColor]];
        [colors addObject:(id)[[UIColor colorWithRed:0.95 green:0.95 blue:0.99 alpha:1.0] CGColor]];
        [colors addObject:(id)[[UIColor colorWithRed:0.77 green:0.77 blue:0.92 alpha:1.0] CGColor]];
    }
    return colors;
}
