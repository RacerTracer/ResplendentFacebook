//
//  RFBNativeParamsBuilder.h
//  Racer Tracer
//
//  Created by Benjamin Maer on 8/12/14.
//  Copyright (c) 2014 Appy Dragon. All rights reserved.
//

#import <Foundation/Foundation.h>





@interface RFBNativeParamsBuilder : NSObject

//Required
@property (nonatomic, strong) NSString* facebookAppId;
-(void)setFacebookAppIdFromMainBundlePlist;

//Optional
@property (nonatomic, strong) NSString* caption;
@property (nonatomic, strong) NSString* shareDescription;
@property (nonatomic, strong) NSString* name;
@property (nonatomic, strong) NSString* linkUrl;
@property (nonatomic, strong) NSString* pictureUrl;

-(NSDictionary*)createParamsDictionary;

@end
