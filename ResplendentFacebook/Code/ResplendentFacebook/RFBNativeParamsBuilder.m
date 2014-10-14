//
//  RFBNativeParamsBuilder.m
//  Racer Tracer
//
//  Created by Benjamin Maer on 8/12/14.
//  Copyright (c) 2014 Appy Dragon. All rights reserved.
//

#import "RFBNativeParamsBuilder.h"
#import "RUConditionalReturn.h"
#import "NSBundle+RUPListGetters.h"
#import "NSMutableDictionary+RUUtil.h"





@implementation RFBNativeParamsBuilder

#pragma mark - Facebook Id From Plist
-(void)setFacebookAppIdFromMainBundlePlist
{
	NSString* facebookAppId = [NSBundle mainBundle].ruFacebookAppID;

	kRUConditionalReturn(facebookAppId.length == 0, YES);

	[self setFacebookAppId:facebookAppId];
}

#pragma mark
-(NSDictionary*)createParamsDictionary
{
	kRUConditionalReturn_ReturnValueNil(self.facebookAppId.length == 0, YES);

	NSMutableDictionary* params = [NSMutableDictionary dictionary];

	[params setObjectOrRemoveIfNil:self.facebookAppId forKey:@"app_id"];

	[params setObjectOrRemoveIfNil:self.toFacebookUserId forKey:@"to"];

	[params setObjectOrRemoveIfNil:self.name forKey:@"name"];
	[params setObjectOrRemoveIfNil:self.caption forKey:@"caption"];
	[params setObjectOrRemoveIfNil:self.shareDescription forKey:@"description"];
	[params setObjectOrRemoveIfNil:self.linkUrl forKey:@"link"];
	[params setObjectOrRemoveIfNil:self.pictureUrl forKey:@"picture"];
	[params setObjectOrRemoveIfNil:self.message forKey:@"message"];

	return [params copy];
}

@end
