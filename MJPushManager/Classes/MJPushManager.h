//
//  MJPushManager.h
//  Common
//
//  Created by 黄磊 on 16/4/20.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/// Plist文件名设置
#ifndef PLIST_ACTIVE_PUSHS
#define PLIST_ACTIVE_PUSHS   @"active_pushs"
#endif

@interface MJPushManager : NSObject


+ (instancetype)shareInstance;

#pragma mark - Register

- (void)registerPush:(UIApplication *)application;

- (void)registSucceedWith:(NSData *)deviceToken;

#pragma mark - HandlePush

- (void)handleThisPush:(NSDictionary *)userInfo;

@end


/** UIViewController extension */
// 需要接受push的界面请实现下列方法方法
@interface UIViewController (MJPushManager)
// 使用data初始化界面或添加data对应数据
- (void)configWithData:(id)data;

// 判断最上层界面能否处理推送信息
- (BOOL)canHandleThisPushWithData:(NSDictionary *)pushData;

@end
