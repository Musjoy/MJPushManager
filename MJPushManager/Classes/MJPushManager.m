//
//  MJPushManager.m
//  Common
//
//  Created by 黄磊 on 16/4/20.
//  Copyright © 2016年 Musjoy. All rights reserved.
//

#import "MJPushManager.h"
#import "PushInfoModel.h"
#import "PushHandleModel.h"
#import <AudioToolbox/AudioToolbox.h>
#ifdef HEADER_CONTROLLER_MANAGER
#import HEADER_CONTROLLER_MANAGER
#endif
#ifdef HEADER_NAVIGATION_CONTROLLER
#import HEADER_NAVIGATION_CONTROLLER
#endif
#ifdef MODULE_FILE_SOURCE
#import "FileSource.h"
#endif
#ifdef MODULE_USER_MANAGER
#import "UserManager.h"
#endif
#ifdef MODULE_INTERFACE_MANAGER
#import "MJInterfaceManager.h"
#endif
#ifdef MODULE_DB_MODEL
#import "DBModel.h"
#endif
#ifdef MODULE_PROMOTION_MANAGER
#import "PromotionManager.h"
#endif
#ifdef MODULE_LAUNCH_MANAGER
#import "LaunchManager.h"
#endif


static MJPushManager *s_pushManager = nil;

#pragma mark - Category

@implementation UIViewController(MJPushManager)

- (void)configWithData:(id)data
{
    // need be overwrite
    LogError(@"This View Controller [%@] Not Overwrite This Function", [self class]);
    return;
}


- (BOOL)canHandleThisPushWithData:(NSDictionary *)pushData
{
    return NO;
}

@end


#pragma mark -

@interface MJPushManager ()


@property (nonatomic, assign) int curPushCount;                     ///< 当前处理推送条数
@property (nonatomic, strong) NSString *deviceToken;

@property (nonatomic, strong) NSDictionary *activePushs;

@property (nonatomic, strong) NSMutableDictionary *dicUntreatedPush;    ///< 未处理的推送

@property (nonatomic, assign) BOOL isActive;                        ///< 是否激活


@end

@implementation MJPushManager

+ (instancetype)sharedInstance
{
    static dispatch_once_t once_patch;
    dispatch_once(&once_patch, ^() {
        s_pushManager = [[self alloc] init];
    });
    
    return s_pushManager;
}

- (id)init
{
    self = [super init];
    if (self)
    {
        NSMutableDictionary *aDic = getFileData(FILE_NAME_ACTIVE_PUSHS);
        for (NSString* key in [aDic allKeys]) {
            NSDictionary *value = aDic[key];
            PushHandleModel *aPushHandle = [[PushHandleModel alloc] initWithDictionary:value];
            [aDic setObject:aPushHandle forKey:key];
        }
        _activePushs = aDic;
        _dicUntreatedPush = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Register

/** 注册推送 */
- (void)registerPush:(UIApplication *)application
{
    if (__CUR_IOS_VERSION >=__IPHONE_8_0) {
        [application registerForRemoteNotifications];
        //1.创建消息上面要添加的动作(按钮的形式显示出来)
        UIMutableUserNotificationAction *actionOpen = [[UIMutableUserNotificationAction alloc] init];
        actionOpen.identifier = @"open";//按钮的标示
        actionOpen.title=@"Open";//按钮的标题
        actionOpen.activationMode = UIUserNotificationActivationModeForeground;//当点击的时候启动程序
        //    action.authenticationRequired = YES;
        //    action.destructive = YES;
        
        UIMutableUserNotificationAction *actionReject = [[UIMutableUserNotificationAction alloc] init];
        actionReject.identifier = @"reject";
        actionReject.title=@"Reject";
        actionReject.activationMode = UIUserNotificationActivationModeBackground;//当点击的时候不启动程序，在后台处理
        actionReject.authenticationRequired = YES;//需要解锁才能处理，如果action.activationMode = UIUserNotificationActivationModeForeground;则这个属性被忽略；
        actionReject.destructive = YES;
        
        //2.创建动作(按钮)的类别集合
        UIMutableUserNotificationCategory *categorys = [[UIMutableUserNotificationCategory alloc] init];
        categorys.identifier = @"alert";//这组动作的唯一标示,推送通知的时候也是根据这个来区分
        [categorys setActions:@[actionOpen,actionReject] forContext:(UIUserNotificationActionContextMinimal)];
        
        //3.创建UIUserNotificationSettings，并设置消息的显示类类型
        UIUserNotificationSettings *notiSettings = [UIUserNotificationSettings settingsForTypes:(UIUserNotificationTypeBadge | UIUserNotificationTypeAlert | UIUserNotificationTypeSound) categories:[NSSet setWithObjects:categorys,nil]];
        [application registerUserNotificationSettings:notiSettings];
    } else {
#if __IPHONE_OS_VERSION_MIN_REQUIRED < __IPHONE_8_0
        [application registerForRemoteNotificationTypes:UIRemoteNotificationTypeAlert | UIRemoteNotificationTypeSound];
#endif
    }
}

- (void)registerPush:(UIApplication *)application withOptions:(NSDictionary *)launchOptions
{
    [self registerPush:application];
    // UIApplicationLaunchOptionsRemoteNotificationKey
    NSDictionary *pushInfo = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if (pushInfo) {
#ifdef MODULE_LAUNCH_MANAGER
        [LaunchManager registerLaunchAction:^{
            [self handleThisLaunchPush:pushInfo];
        }];
#else
        [self performSelector:@selector(handleThisLaunchPush:) withObject:pushInfo afterDelay:3];
#endif
    } else {
        _isActive = YES;
    }
}

- (void)handleThisLaunchPush:(NSDictionary *)pushInfo
{
    
    [self handleThisPush:pushInfo];
    _isActive = YES;
}

- (void)registSucceedWith:(NSData *)deviceToken
{
    [self setDeviceToken:[deviceToken base64EncodedStringWithOptions:0]];
}


#pragma mark - HandlePush

- (void)handleThisPush:(NSDictionary *)userInfo
{
    PushInfoModel *pushInfo = [[PushInfoModel alloc] initWithDictionary:userInfo[@"aps"]];
    pushInfo.message = userInfo[@"aps"][@"alert"];
    
#ifdef MODULE_USER_MANAGER
    UserManager *theUser = [UserManager sharedInstance];
    if ([pushInfo.pushToUserId intValue] != 0) {
        NSNumber *userId = [theUser getUserId];
        if (userId == nil) {
            LogTrace(@" Ingnore This Push, Because the current userId is nil, while pushToUserId(: %@)", pushInfo.pushToUserId);
            return;
        }
        if (![pushInfo.pushToUserId isEqualToNumber:[theUser getUserId]]) {
            LogTrace(@" Ingnore This Push, Because the pushToUserId(: %@) is not equal to userId(: %@)", pushInfo.pushToUserId, [theUser getUserId]);
            return;
        }
    }
#endif
    
    PushHandleModel *activePush = [_activePushs objectForKey:pushInfo.pushType];
    if (activePush) {
        NSMutableDictionary *aDic = [objectFromString(pushInfo.contentIds, nil) mutableCopy];
        if ([self appIsActive]) {
            if (pushInfo.sound.length > 0) {
                // 播放震动
                AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
                
                // 播放音频
                SystemSoundID soundID;
                NSString *pushSound = [NSString stringWithFormat:@"push_sound_%@", pushInfo.sound];
                NSString *soundFile = [[NSBundle mainBundle] pathForResource:pushSound ofType:@"mp3"];
                // 一个指向文件位置的CFURLRef对象和一个指向要设置的SystemSoundID变量的指针
                AudioServicesCreateSystemSoundID((__bridge CFURLRef)[NSURL fileURLWithPath:soundFile], &soundID);
                AudioServicesPlaySystemSound(soundID);
            }            
        } else {
            [aDic setObject:@YES forKey:@"directShow"];
        }
        [aDic setObject:pushInfo.message forKey:@"message"];
        [aDic setObject:pushInfo.pushType forKey:@"pushType"];
        activePush.pushData = aDic;
        [self distributeThisPushWith:activePush];
        [self pushHandled:pushInfo.pushId];
    } else {
        LogError(@"Receive Undefined Push");
    }
    
}

#pragma mark - Private


- (void)distributeThisPushWith:(PushHandleModel *)pushHandle
{
//    LogTrace(@" Distribute This Push : %@", [pushHandle toJSONString]);
    _curPushCount++;
    PushHandleType handleType = pushHandle.handleType;
    NSString *notificationName = pushHandle.notificationName;
    // 只要设置通知名称就推送通知
    if (notificationName.length > 0) {
        [[NSNotificationCenter defaultCenter] postNotificationName:notificationName object:pushHandle.pushData];
    }
    
    if (handleType == ePushDoNothing) {
        // 如果是只发送通知，则不进行下面操作
        return;
    }
    if (handleType == ePushSetDefault) {
        [self setDefaultValueWith:pushHandle];
        return;
    }
    
    // 打开App Store
    if (handleType == ePushOpenAppStore) {
#ifdef MODULE_PROMOTION_MANAGER
        [[PromotionManager sharedInstance] promoteApp:pushHandle.pushData];
#endif
        return;
    }
    
    //  执行对应方法
    if (handleType == ePushExecuteFunction) {
        NSString *handlerClass = pushHandle.pushData[@"handlerClass"]?:pushHandle.handlerClass;
        NSString *strAction = pushHandle.pushData[@"action"]?:pushHandle.action;
        if (handlerClass.length > 0 && strAction.length > 0) {
            @try {
                Class theClass = NSClassFromString(handlerClass);
                NSObject *theHanlder = [theClass sharedInstance];
                [self dataByExecute:strAction target:theHanlder data:pushHandle.pushData];
            } @catch (NSException *exception) {
                
            }
        }
        return;
    }
    
    if (handleType == ePushOpenDetailView
        || handleType == ePushOpenDetailViewWithAlert) {
        UIViewController *aTopVC = [self.class topViewController];
        if (![aTopVC canHandleThisPushWithData:pushHandle.pushData]) {
            if ([self appIsActive]) {
                // 应用在前台
                pushHandle.topVC = aTopVC;
                [_dicUntreatedPush setObject:pushHandle forKey:[NSString stringWithFormat:@"%d", _curPushCount]];
                if (handleType == ePushOpenDetailView) {
                    [self showNotificationWithMessage:pushHandle.pushData[kMessage]];
                } else {
                    [self showAlertWith:pushHandle];
                }
            } else {
                // 应用在后台，调用方法直接显示界面
                [self showViewControllerWith:pushHandle];
            }
        }
    }
}


- (void)showNotificationWithMessage:(NSString *)aMessage
{
    
}

- (void)showAlertWith:(PushHandleModel *)pushHandle
{
    NSString *title = pushHandle.pushData[kTitle];
    NSString *content = pushHandle.pushData[kMessage];
    NSString *go = pushHandle.pushData[kGoSee];
    if (go.length == 0) {
        if (pushHandle.handleType == ePushOpenAppStore) {
            go = @"Get Now";
        } else {
            go = @"Show Detail";
        }
    }
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:content delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:go, nil];
    
    [alert setTag:_curPushCount];
    
    [alert show];
}

- (void)setDefaultValueWith:(PushHandleModel *)pushHandle
{
    NSString *type = pushHandle.pushData[@"type"];
    NSObject *data = pushHandle.pushData[@"data"];
    if (type.length == 0 || data == nil) {
        return;
    }
    if ([type isEqualToString:@"reset-key"]) {
        // UserDefault 重置
        if ([data isKindOfClass:[NSArray class]]) {
            NSArray *arrKeys = (NSArray *)data;
            if (arrKeys.count > 0) {
                for (NSString *aKey in arrKeys) {
                    [[NSUserDefaults standardUserDefaults] removeObjectForKey:aKey];
                }
                [self alert:@"Reset value succeed! Please close the application and restart it."];
            }
        } else if ([data isKindOfClass:[NSString class]]) {
            NSString *aKey = (NSString *)data;
            if (aKey.length > 0) {
                [[NSUserDefaults standardUserDefaults] removeObjectForKey:aKey];
                [self alert:@"Reset value succeed! Please close the application and restart it."];
            }
        }
    } else if ([type isEqualToString:@"set-default"]) {
        if ([data isKindOfClass:[NSDictionary class]]) {
            NSDictionary *aDic = (NSDictionary *)data;
        
            if (aDic.allKeys.count > 0) {
                for (NSString *aKey in aDic.allKeys) {
                    NSObject *aValue = aDic[aKey];
                    if (aValue) {
                        [[NSUserDefaults standardUserDefaults] setObject:aValue forKey:aKey];
                    }
                }
                [self alert:@"Set default value succeed! Please close the application and restart it."];
            }
        }
    }
}

// 显示推送内容对应界面
- (void)showViewControllerWith:(PushHandleModel *)pushHandle
{
#ifdef MODULE_CONTROLLER_MANAGER
    NSString *strDisplayVC = pushHandle.displayVC;
    if (strDisplayVC.length == 0) {
        // 不存在显示推送的界面，直接返回
        return;
    }
    
    BOOL showInRoot = pushHandle.showInRoot;
    BOOL usePresent = pushHandle.usePresent;
    
    UINavigationController *aNavVC = nil;
    if (showInRoot) {
        [THEControllerManager popToRootViewControllerAnimated:NO];
        //        aNavVC = [ControllerManager rootNavViewController];
    } else {
        aNavVC = [THEControllerManager topNavViewController];
    }
    
    // 初始化并显示该界面
    Class displayVC = NSClassFromString(strDisplayVC);
    UIViewController *aVC = [self.class getViewControllerWithName:strDisplayVC];
    [aVC configWithData:pushHandle.pushData];
    if (![aNavVC.topViewController isViewLoaded]) {
        usePresent = YES;
    }
    if (usePresent) {
        THENavigationController *navVC = [[THENavigationController alloc] initWithRootViewController:aVC];
        [aNavVC presentViewController:navVC animated:YES completion:nil];
    } else {
        [aNavVC pushViewController:aVC animated:YES];
    }
#else
    LogError(@"Cann't use this function without ControllerManager!");
#endif
}



- (BOOL)appIsActive
{
    if (!_isActive) {
        return _isActive;
    }
    return ([UIApplication sharedApplication].applicationState == UIApplicationStateActive);
}


#pragma mark - 

- (void)setDeviceToken:(NSString *)deviceToken
{
    if (deviceToken.length > 0) {
        _deviceToken = deviceToken;
#ifdef MODULE_INTERFACE_MANAGER
        [MJInterfaceManager registerPush:deviceToken completion:^(BOOL isSucceed, NSString *message, id data) {
            if (isSucceed) {
                
            }
        }];
#endif
    }
}

- (void)pushHandled:(NSNumber *)pushId
{
    if (pushId == nil) {
        return;
    }
#ifdef MODULE_INTERFACE_MANAGER
    [MJInterfaceManager pushHandled:pushId completion:^(BOOL isSucceed, NSString *message, id data) {
        
    }];
#endif
}


#pragma mark - UIAlertViewDelegate

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    NSString *key = [NSString stringWithFormat:@"%d", (int)alertView.tag];
    PushHandleModel *pushHandle = _dicUntreatedPush[key];
    if (pushHandle) {
        if (buttonIndex > 0) {
            [self showViewControllerWith:pushHandle];
        }
        [_dicUntreatedPush removeObjectForKey:key];
    }
}



#pragma mark - Other Function

- (void)alert:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}


- (id)dataByExecute:(NSString *)strAction target:(id)theHanlder data:(id)jsonData
{
    id dataReceive = nil;
    if (strAction.length > 0) {
        SEL selector = NSSelectorFromString(strAction);
        if ([theHanlder respondsToSelector:selector]) {
            if ([strAction hasSuffix:@":"]) {
                IMP imp = [theHanlder methodForSelector:selector];
                id (*func)(id, SEL, id) = (void *)imp;
                dataReceive = func(theHanlder, selector, jsonData);
            } else {
                IMP imp = [theHanlder methodForSelector:selector];
                id (*func)(id, SEL) = (void *)imp;
                dataReceive = func(theHanlder, selector);
            }
        }
    }
    return dataReceive;
}

+ (UIViewController *)getViewControllerWithName:(NSString *)aVCName
{
#ifdef MODULE_CONTROLLER_MANAGER
    return [THEControllerManager getViewControllerWithName:aVCName];
#else
    Class classVC = NSClassFromString(aVCName);
    if (classVC) {
        // 存在该类
        NSString *filePath = [[NSBundle mainBundle] pathForResource:aVCName ofType:@"nib"];
        UIViewController *aVC = nil;
        if (filePath.length > 0) {
            aVC = [[classVC alloc] initWithNibName:aVCName bundle:nil];
        } else {
            aVC = [[classVC alloc] init];
        }
        return aVC;
    }
    return nil;
#endif
}


+ (UIViewController *)topViewController
{
#ifdef MODULE_CONTROLLER_MANAGER
    return [THEControllerManager topNavViewController];
#else
    UIViewController *topVC = nil;
    
    // Find the top window (that is not an alert view or other window)
    UIWindow *topWindow = [[UIApplication sharedApplication] keyWindow];
    if (topWindow.windowLevel != UIWindowLevelNormal) {
        NSArray *windows = [[UIApplication sharedApplication] windows];
        for(topWindow in windows) {
            if (topWindow.windowLevel == UIWindowLevelNormal)
                break;
        }
    }
    
    UIView *rootView = [[topWindow subviews] objectAtIndex:0];
    id nextResponder = [rootView nextResponder];
    
    if ([nextResponder isKindOfClass:[UIViewController class]]) {
        topVC = nextResponder;
    } else if ([topWindow respondsToSelector:@selector(rootViewController)] && topWindow.rootViewController != nil) {
        topVC = topWindow.rootViewController;
    } else {
        NSAssert(NO, @"Could not find a root view controller.");
    }
    
    UIViewController *presentVC = topVC.presentedViewController;
    while (presentVC) {
        topVC = presentVC;
        presentVC = topVC.presentedViewController;
    }
    return topVC;
#endif
}

@end
