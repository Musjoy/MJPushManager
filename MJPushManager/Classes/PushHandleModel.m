//
//  PushHandleModel.m
//  Common
//
//  Created by 黄磊 on 16/6/20.
//  Copyright © 2016年 Tomobapps. All rights reserved.
//

#import "PushHandleModel.h"

@interface PushHandleModel ()


@end


@implementation PushHandleModel

- (id)initWithDictionary:(NSDictionary *)aDic
{
    self = [super init];
    if (self) {
        self.handleType = [aDic[@"handleType"] intValue];
        self.notificationName = aDic[@"notificationName"];
        self.displayVC = aDic[@"displayVC"];
        self.usePresent = [aDic[@"usePresent"] boolValue];
        self.showInRoot = [aDic[@"showInRoot"] boolValue];
    }
    return self;
}

@end
