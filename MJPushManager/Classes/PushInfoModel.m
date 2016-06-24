//
//  PushInfoModel.m
//  Common
//
//  Created by 黄磊 on 16/4/20.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "PushInfoModel.h"

@implementation PushInfoModel

- (id)initWithDictionary:(NSDictionary *)aDic
{
    self = [super init];
    if (self) {
        self.pushId = aDic[@"pushId"];
        self.pushType = aDic[@"pushType"];
        self.contentIds = aDic[@"contentIds"];
        self.pushToUserId = aDic[@"pushToUserId"];
        self.message = aDic[@"message"];
        self.sound = aDic[@"sound"];
    }
    return self;
}

@end
