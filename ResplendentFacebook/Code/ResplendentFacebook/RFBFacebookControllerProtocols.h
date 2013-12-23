//
//  RUFacebookControllerProtocols.h
//  Pineapple
//
//  Created by Benjamin Maer on 2/23/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RFBFacebookController;
@class FBAccessTokenData;

@protocol RFBFacebookControllerDelegate <NSObject>

- (void)facebookController:(RFBFacebookController*)facebookController didLogInWithToken:(FBAccessTokenData*)token;
- (void)facebookController:(RFBFacebookController*)facebookController didFailWithError:(NSError*)error;
- (void)facebookControllerClearedToken:(RFBFacebookController*)facebookController;

@end
