//
//  RUFacebookController.h
//  Pineapple
//
//  Created by Benjamin Maer on 2/23/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "RFBFacebookControllerProtocols.h"
#import <FacebookSDK/FBWebDialogs.h>

/*
 To compile, the following is required:
 1) In Target's Build settings, add "-lsqlite3.0" to Linking->Other Linking Flags
 2) Add Social, AdSupport, and Accounts, making them all optional if supporting pre 6.0

 For proper implementation, the following must be done:
 1) Add all the methods listed under "Application Delegate Methods" to their respective AppDelegate's methods
 */

@interface RFBFacebookController : NSObject


@property (nonatomic, assign) id<RFBFacebookControllerDelegate> delegate;

//Subclasses can overload
@property (nonatomic, readonly) FBSession* currentSession; //If nil, will use [FBSession activeSession]
@property (nonatomic, readonly) FBAccessTokenData* accessTokenData; //default implementation uses self.currentSession.accessTokenData.
@property (nonatomic, readonly) NSArray* readPermissions;
@property (nonatomic, readonly) NSArray* publishPermissions;

//Share on facebook variables. Subclasses should overloaded
@property (nonatomic, readonly) NSString* shareLink;
@property (nonatomic, readonly) NSString* shareName;
@property (nonatomic, readonly) NSString* shareCaption;
@property (nonatomic, readonly) NSString* shareDescription;

//Performs clear and calls delegate
- (void)logout;

-(void)closeFacebookSession;

//Method used to login.
- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI;

//Application Delegate Methods
- (BOOL)applicationOpenedURL:(NSURL *)url;
- (void)applicationWillTerminate;
- (void)applicationDidBecomeActive;

//Share on facebook actions
-(void)sendInviteToFriendViaMessageWithFacebookId:(NSString*)facebookId message:(NSString*)message title:(NSString*)title;
-(void)showInviteOnFriendsWallWithFacebookId:(NSString*)facebookId;

//Native modals
-(void)presentNativeFeedDialogModallyWithSessionWithDescription:(NSString*)description handler:(FBWebDialogHandler)handler;

//Meant to be overloaded by subclasses. Should never be called directly.
-(void)didFinishPostingToWallOfUserWithFacebookId:(NSString*)facebookId result:(FBWebDialogResult)result resultURL:(NSURL*)resultURL error:(NSError*)error;

-(NSDictionary*)parseURLParams:(NSString *)query;

@end
