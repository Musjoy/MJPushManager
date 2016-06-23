//
//  PushHandleModel.h
//  Common
//
//  Created by 黄磊 on 16/6/20.
//  Copyright © 2016年 Tomobapps. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// 推送信息
static NSString *const kMessage         = @"message";
// 推送标题
static NSString *const kTitle           = @"kTitle";
// 查看详情
static NSString *const kGoSee           = @"go";

// push处理方式
typedef enum {
    ePushDoNothing,                         ///< 接受但不做处理
    ePushSetDefault,                        ///< 设置NSUserDefault
    ePushOpenAppStore,                      ///< 打开推广App信息页
    ePushOpenDetailViewWithAlert,           ///< 打开相应界面，应用在前台，先弹窗
    ePushOpenDetailView,                    ///< 打开相应界面，应用在前台，状态栏显示消息
    ePushExecuteFunction                    ///< 执行特定方法
} PushHandleType;


@interface PushHandleModel : NSObject

@property (nonatomic, assign) PushHandleType handleType;            ///< 推送的类型
@property (nonatomic, strong) NSString *notificationName;           ///< 推送携带的Id，可能是任何Id，如服务Id
@property (nonatomic, strong) NSString *displayVC;                  ///< 推送需要显示的VC
@property (nonatomic, assign) BOOL usePresent;                      ///< 是否使用present的方式弹出
@property (nonatomic, assign) BOOL showInRoot;                      ///<  是否需要在根目录上弹出

@property (nonatomic, strong) NSDictionary *pushData;               ///< 推送数据

@property (nonatomic, strong) UIViewController *topVC;              ///< 当前顶部的VC

@property (nonatomic, strong) NSString *handlerClass;               ///< 处理该推送的类
@property (nonatomic, strong) NSString *action;                     ///< 处理该推送的方法

- (id)initWithDictionary:(NSDictionary *)aDic;

@end
