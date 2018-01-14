//
//  LoginViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 31/12/2014.
//
//

#import <UIKit/UIKit.h>

@interface LoginViewController : UIViewController

- (void)requestRequestToken: (UINavigationController*)nc;

@property (strong, nonatomic) IBOutlet UIWebView *webView;

@end
