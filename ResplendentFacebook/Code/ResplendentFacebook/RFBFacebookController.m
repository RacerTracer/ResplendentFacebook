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

#import <FacebookSDK/FacebookSDK.h>





@interface RFBFacebookController ()

@property (nonatomic, readonly) FBSession* _currentSession;

-(NSMutableDictionary*)webDialogShareParamsWithTargetShareUserId:(NSString*)facebookId;

- (void)sessionStateChanged:(FBSession *)session state:(FBSessionState) state error:(NSError *)error;

- (void)clearFacebookSession;

-(void)presentNativeFeedDialogModallyWithSessionWithFBSession:(FBSession*)fbSession handler:(FBWebDialogHandler)handler;

@end





@implementation RFBFacebookController

#pragma mark - Public instance methods

/*
 * Opens a Facebook session and optionally shows the login UX.
 */
- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI
{
    return [FBSession openActiveSessionWithReadPermissions:self.readPermissions allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState state, NSError *error) {
        [self sessionStateChanged:session state:state error:error];
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
	NSMutableDictionary* params = [self webDialogShareParamsWithTargetShareUserId:facebookId];
	
	if (params)
	{
		[FBWebDialogs presentRequestsDialogModallyWithSession:self._currentSession message:message title:title parameters:params handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
            [self didFinishPostingToWallOfUserWithFacebookId:facebookId result:result resultURL:resultURL error:error];
        }];
	}
}

-(void)showInviteOnFriendsWallWithFacebookId:(NSString*)facebookId
{
	NSMutableDictionary* params = [self webDialogShareParamsWithTargetShareUserId:facebookId];

	if (params)
	{
		[FBWebDialogs presentFeedDialogModallyWithSession:self._currentSession parameters:params handler:^(FBWebDialogResult result, NSURL *resultURL, NSError *error) {
            [self didFinishPostingToWallOfUserWithFacebookId:facebookId result:result resultURL:resultURL error:error];
        }];
	}
}

#pragma mark - Post Action methods
-(void)didFinishPostingToWallOfUserWithFacebookId:(NSString*)facebookId result:(FBWebDialogResult)result resultURL:(NSURL*)resultURL error:(NSError*)error
{
    if (error)
    {
        RUDLog(@"error: %@",error);
    }
    
    RUDLog(@"resultURL: %@",resultURL);
}

#pragma mark - Parsing
-(NSDictionary*)parseURLParams:(NSString *)query
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

#pragma mark - Params
-(NSMutableDictionary*)webDialogShareParamsWithTargetShareUserId:(NSString*)facebookId
{
	NSDictionary *dict = [[NSBundle mainBundle] infoDictionary];
    NSString* facebookAppId = [dict objectForKey:@"FacebookAppID"];
	
    if (facebookAppId.length)
    {
        NSMutableDictionary* params = [NSMutableDictionary dictionaryWithDictionary:@{@"app_id": facebookAppId,@"to":facebookId}];
        
		[params setObjectOrRemoveIfNil:[self shareLink] forKey:@"link"];
		[params setObjectOrRemoveIfNil:[self shareName] forKey:@"name"];
		[params setObjectOrRemoveIfNil:[self shareCaption] forKey:@"caption"];
		[params setObjectOrRemoveIfNil:[self shareDescription] forKey:@"description"];

		return params;
	}
	else
	{
		return nil;
	}
}

#pragma mark - Native Feed Dialog
-(void)presentNativeFeedDialogModallyWithSessionWithFBSession:(FBSession*)fbSession handler:(FBWebDialogHandler)handler
{
	RFBNativeParamsBuilder* nativeParamsBuilder = [RFBNativeParamsBuilder new];

	[nativeParamsBuilder setFacebookAppIdFromMainBundlePlist];

	[nativeParamsBuilder setName:self.shareName];
	[nativeParamsBuilder setShareDescription:self.shareDescription];
	[nativeParamsBuilder setCaption:self.shareCaption];
	[nativeParamsBuilder setLinkUrl:self.shareLink];

	NSDictionary* params = [nativeParamsBuilder createParamsDictionary];
	
	[FBWebDialogs presentFeedDialogModallyWithSession:fbSession parameters:params handler:handler];
}

-(void)presentNativeFeedDialogModallyWithSessionWithHandler:(FBWebDialogHandler)handler
{
	FBSession* currentSession = self.currentSession;
	if (currentSession)
	{
		[self presentNativeFeedDialogModallyWithSessionWithFBSession:currentSession handler:handler];
	}
	else
	{
		[FBSession openActiveSessionWithReadPermissions:self.readPermissions allowLoginUI:YES completionHandler:^(FBSession *session, FBSessionState status, NSError *error) {
			
			[self presentNativeFeedDialogModallyWithSessionWithFBSession:session handler:handler];
			
		}];
	}
}

@end
