//
//  NetWorkTool.h
//  CFNetwork_Demo
//
//  Created by 李一贤 on 2019/5/21.
//  Copyright © 2019 atomlee. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface NetWorkTool : NSObject

+ (instancetype)shareInstance;

-(void)postUrl;

//-(NSString*)processParams;

@end

NS_ASSUME_NONNULL_END
