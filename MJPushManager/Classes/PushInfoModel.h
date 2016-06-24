//
//  PushInfoModel.h
//  Common
//
//  Created by 黄磊 on 16/4/20.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PushInfoModel : NSObject

@property (nonatomic, strong) NSString *pushId;                     ///< 推送Id
@property (nonatomic, strong) NSString *pushType;                   ///< 推送的类型
@property (nonatomic, strong) NSString *contentIds;                 ///< 推送携带的Id，可能是任何Id，如服务Id
@property (nonatomic, strong) NSNumber *pushToUserId;               ///< 推送针对的用户Id
@property (nonatomic, strong) NSString *message;                    ///< 推送的消息
@property (nonatomic, strong) NSString *sound;                      ///< 推送声音
//@property (nonatomic, strong) NSString *title;                      ///< 推送标题

- (id)initWithDictionary:(NSDictionary *)aDic;


@end
