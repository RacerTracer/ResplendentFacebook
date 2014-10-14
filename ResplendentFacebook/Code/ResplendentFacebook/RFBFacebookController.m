//
//  RUFacebookController.m
//  Pineapple
//
//  Created by Benjamin Maer on 2/23/13.
//  Copyright (c) 2013 Pineapple. All rights reserved.
//

#import "RFBFacebookController.h"
#import "RUDLog.h"
#import "RUConstants.h"
#import "NSMutableDictionary+RUUtil.h"
#import "RFBNativeParamsBuilder.h"
#import "RUConditionalReturn.h"

#import <FacebookSDK/FacebookSDK.h>





@interface RFBFacebookController ()

@property (nonatomic, readonly) FBSession* _currentSession;

-(RFBNativeParamsBuilder*)createNativeParamsBuilderWithCurrentSettings;

//-(NSMutableDictionary*)webDialogShareParamsWithTargetShareUserId:(NSString*)facebookId;

- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error;

- (void)clearFacebookSession;

-(void)presentFeedDialogModallyWithCurrentShareParamsAndHandler:(FBWebDialogHandler)handler;

@end





@implementation RFBFacebookController

#pragma mark - Public instance methods

/*
 * Opens a Facebook session and optionally shows the login UX.
 */
- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI
{
	return [self openSessionWithAllowLoginUI:allowLoginUI completionHandler:nil];
}

- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI completionHandler:(FBSessionStateHandler)handler
{
    return [FBSession openActiveSessionWithReadPermissions:self.readPermissions allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
        [self sessionStateChanged:session state:state error:error];

		if (handler)
		{
			handler(session,state,error);
		}
    }];
}

/*
 * If we have a valid session at the time of openURL call, we handle
 * Facebook transitions by passing the url argument to handleOpenURL
 */
- (BOOL)applicationOpenedURL:(NSURL *)url
{
    // attempt to extract a token from the url
    return [FBSession.activeSession handleOpenURL:url];
}

- (void)applicationWillTerminate
{
    [FBSession.activeSession close];
}

- (void)applicationDidBecomeActive
{
    [FBSession.activeSession handleDidBecomeActive];
}

-(void)closeFacebookSession
{
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (void)logout
{
    FBSessionState state = FBSession.activeSession.state;
    [self clearFacebookSession];
    if (state != FBSession.activeSession.state)
        [self sessionStateChanged:FBSession.activeSession state:FBSession.activeSession.state error:nil];
}

#pragma mark - Private instance methods
-(void)clearFacebookSession
{
    [self closeFacebookSession];
    [FBSession.activeSession close];
    [FBSession setActiveSession:nil];
}

/*
 * Callback for session changes.
 */
- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error
{
    switch (state)
    {
        case FBSessionStateOpen:
            if (error)
            {
                RUDLog(@"FBSessionStateOpen had error %@",error.localizedDescription);
                [self.delegate facebookController:self didFailWithError:error];
            }
            else
            {
                // We have a valid session
                [self.delegate facebookController:self didLogInWithToken:session.accessTokenData];
            }
            break;
            
        case FBSessionStateClosed:
        case FBSessionStateClosedLoginFailed:
            [self clearFacebookSession];
            [self.delegate facebookControllerClearedToken:self];
            break;
            
        default:
            RUDLog(@"unhandled facebook state %i",state);
            break;
    }
}

#pragma mark - Publishing
-(BOOL)currentSessionsContainPublishPermissions
{
	kRUConditionalReturn_ReturnValueFalse(self.currentSession == nil, YES);

	for (NSString* publishPermission in self.publishPermissions)
	{
		if ([self.currentSession.permissions containsObject:publishPermission] == false)
		{
			return NO;
		}
	}

	return YES;
}

-(BOOL)registerForPublishPermissionsForDefaultAudience:(FBSessionDefaultAudience)defaultAudience completion:(FBSessionRequestPermissionResultHandler)completion
{
	kRUConditionalReturn_ReturnValueFalse(self.currentSession == nil, YES);
	kRUConditionalReturn_ReturnValueFalse(self.currentSessionsContainPublishPermissions, NO);

	[self.currentSession requestNewPublishPermissions:self.publishPermissions
									  defaultAudience:defaultAudience
									completionHandler:completion];

	return YES;
}

-(void)postToFeedForUserWithId:(NSString*)facebookUserId
					   handler:(FBWebDialogHandler)handler
{
	RFBNativeParamsBuilder* nativeParamsBuilder = [self createNativeParamsBuilderWithCurrentSettings];
	[nativeParamsBuilder setToFacebookUserId:facebookUserId];
	NSDictionary* params = [nativeParamsBuilder createParamsDictionary];

	[self presentFeedDialogModallyWithParams:params handler:handler];
}

-(void)presentFeedDialogModallyWithParams:(NSDictionary*)params
								  handler:(FBWebDialogHandler)handler
{
	[FBWebDialogs presentFeedDialogModallyWithSession:self._currentSession parameters:params handler:handler];
}

-(void)presentFeedDialogModallyWithCurrentShareParamsAndHandler:(FBWebDialogHandler)handler
{
	RFBNativeParamsBuilder* nativeParamsBuilder = [self createNativeParamsBuilderWithCurrentSettings];
	
	NSDictionary* params = [nativeParamsBuilder createParamsDictionary];
	
	[self presentFeedDialogModallyWithParams:params handler:handler];
}

#pragma mark - Getter methods
-(FBSession *)_currentSession
{
	return (self.currentSession ?: [FBSession activeSession]);
}

-(FBAccessTokenData *)accessTokenData
{
    return self.currentSession.accessTokenData;
}

#pragma mark - Static Share Actions
-(void)sendInviteToFriendViaMessageWithFacebookId:(NSString*)facebookId message:(NSString*)message title:(NSString*)title
{
	RFBNativeParamsBuilder* paramsBuilder = [self createNativeParamsBuilderWithCurrentSettings];
	[paramsBuilder setToFacebookUserId:facebookId];

	NSDictionary* params = [paramsBuilder createParamsDictionary];

	[FBWebDialogs presentRequestsDialogModallyWithSession:self._currentSession message:message title:title parameters:params handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
		[self didFinishPostingToWallOfUserWithFacebookId:facebookId result:result resultURL:resultURL error:error];
	}];
}

-(void)showInviteOnFriendsWallWithFacebookId:(NSString*)facebookId
{
	RFBNativeParamsBuilder* paramsBuilder = [self createNativeParamsBuilderWithCurrentSettings];
	[paramsBuilder setToFacebookUserId:facebookId];
	
	NSDictionary* params = [paramsBuilder createParamsDictionary];

	[self presentFeedDialogModallyWithParams:params handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
		[self didFinishPostingToWallOfUserWithFacebookId:facebookId result:result resultURL:resultURL error:error];
	}];
}

#pragma mark - Post Action methods
+(BOOL)completedWebDialogWasSuccessWithResultUrl:(NSURL*)resultURL
{
	NSDictionary *urlParams = kRUDictionaryOrNil([self parseURLParams:[resultURL query]]);
	
	NSString* facebookIdFromUrlParams = (urlParams ? [urlParams objectForKey:@"to[0]"] : nil);
	if (facebookIdFromUrlParams.length)
	{
		return YES;
	}
	
	NSString* postId = (urlParams ? [urlParams objectForKey:@"post_id"] : nil);
	if (postId.length)
	{
		return YES;
	}

	return NO;
}

-(void)didFinishPostingToWallOfUserWithFacebookId:(NSString*)facebookId result:(FBWebDialogResult)result resultURL:(NSURL*)resultURL error:(NSError*)error
{
    if (error)
    {
        RUDLog(@"error: %@",error);
    }
    
    RUDLog(@"resultURL: %@",resultURL);

	if (facebookId.length == 0)
	{
		NSAssert(FALSE, @"Must have facebookId");
		return;
	}
	
	switch (result)
	{
		case FBWebDialogResultDialogCompleted:
		{
			if ([self.class completedWebDialogWasSuccessWithResultUrl:resultURL])
			{
				RUDLog(@"success!");
			}
		}
			break;
			
		case FBWebDialogResultDialogNotCompleted:
			break;
	}
}

#pragma mark - Parsing
+(NSDictionary*)parseURLParams:(NSString *)query
{
	NSString* decodedQuery = [query stringByReplacingPercentEscapesUsingEncoding:NSASCIIStringEncoding];

    NSArray *pairs = [decodedQuery componentsSeparatedByString:@"&"];
    NSMutableDictionary *params = [NSMutableDictionary new];
    
    for (NSString *pair in pairs)
    {
        NSArray *kv = [pair componentsSeparatedByString:@"="];
        NSString *val = [[kv objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        
        [params setObject:val forKey:[kv objectAtIndex:0]];
    }
    
    return params;
}

#pragma mark - NativeParamsBuilder
-(RFBNativeParamsBuilder*)createNativeParamsBuilderWithCurrentSettings
{
	RFBNativeParamsBuilder* nativeParamsBuilder = [RFBNativeParamsBuilder new];
	
	[nativeParamsBuilder setFacebookAppIdFromMainBundlePlist];
	
	[nativeParamsBuilder setName:self.shareName];
	[nativeParamsBuilder setShareDescription:self.shareDescription];
	[nativeParamsBuilder setCaption:self.shareCaption];
	[nativeParamsBuilder setLinkUrl:self.shareLink];

	return nativeParamsBuilder;
}

#pragma mark - Native Feed Dialog
-(void)presentNativeFeedDialogModallyWithSessionWithHandler:(FBWebDialogHandler)handler
{
	if (self._currentSession)
	{
		[self presentFeedDialogModallyWithCurrentShareParamsAndHandler:handler];
	}
	else
	{
		[self openSessionWithAllowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {

			[self presentFeedDialogModallyWithCurrentShareParamsAndHandler:handler];

		}];
	}
}

@end
