//
//  LoginViewController.h
//  iXolr
//
//  Created by Bryan Boreham on 31/12/2014.
//
//

#import <UIKit/UIKit.h>
#import <AuthenticationServices/AuthenticationServices.h>

@interface LoginViewController : UIViewController<ASWebAuthenticationPresentationContextProviding>

@property bool useSafari;
- (void)requestRequestToken: (UINavigationController*)nc;

@end
