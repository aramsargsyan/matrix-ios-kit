/*
 Copyright 2016 OpenMarket Ltd
 Copyright 2017 Vector Creations Ltd
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "MXKDeviceView.h"

#import "NSBundle+MatrixKit.h"

#import "MXKConstants.h"

static NSAttributedString *verticalWhitespace = nil;

@interface MXKDeviceView ()
{
    /**
     The displayed device
     */
    MXDevice *mxDevice;
    
    /**
     The matrix session.
     */
    MXSession *mxSession;
    
    /**
     The current alert
     */
    MXKAlert *currentAlert;
    
    /**
     Current request in progress.
     */
    MXHTTPOperation *mxCurrentOperation;
}
@end

@implementation MXKDeviceView

- (void)awakeFromNib
{
    [super awakeFromNib];
    
    // Add tap recognizer to discard the view on bg view tap
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onBgViewTap:)];
    [tap setNumberOfTouchesRequired:1];
    [tap setNumberOfTapsRequired:1];
    [tap setDelegate:self];
    [self.bgView addGestureRecognizer:tap];
    
    _defaultTextColor = [UIColor blackColor];
    
    // Add shadow on added view
    _containerView.layer.cornerRadius = 5;
    _containerView.layer.shadowOffset = CGSizeMake(0, 1);
    _containerView.layer.shadowOpacity = 0.5f;
    
    // Localize string
    [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"ok"] forState:UIControlStateNormal];
    [_cancelButton setTitle:[NSBundle mxk_localizedStringForKey:@"ok"] forState:UIControlStateHighlighted];
    
    [_renameButton setTitle:[NSBundle mxk_localizedStringForKey:@"rename"] forState:UIControlStateNormal];
    [_renameButton setTitle:[NSBundle mxk_localizedStringForKey:@"rename"] forState:UIControlStateHighlighted];
    
    [_deleteButton setTitle:[NSBundle mxk_localizedStringForKey:@"delete"] forState:UIControlStateNormal];
    [_deleteButton setTitle:[NSBundle mxk_localizedStringForKey:@"delete"] forState:UIControlStateHighlighted];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    // Scroll to the top the text view content
    self.textView.contentOffset = CGPointZero;
}

- (void)removeFromSuperviewDidUpdate:(BOOL)isUpdated
{
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    if (mxCurrentOperation)
    {
        [mxCurrentOperation cancel];
        mxCurrentOperation = nil;
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(dismissDeviceView:didUpdate:)])
    {
        [self.delegate dismissDeviceView:self didUpdate:isUpdated];
    }
    else
    {
        [self removeFromSuperview];
    }
}

- (instancetype)initWithDevice:(MXDevice*)device andMatrixSession:(MXSession*)session
{
    NSArray *nibViews = [[NSBundle bundleForClass:[MXKDeviceView class]] loadNibNamed:NSStringFromClass([MXKDeviceView class])
                                                                                      owner:nil
                                                                                    options:nil];
    self = nibViews.firstObject;
    if (self)
    {
        mxDevice = device;
        mxSession = session;
        
        [self setTranslatesAutoresizingMaskIntoConstraints: NO];
        
        if (mxDevice)
        {
            // Device information
            NSMutableAttributedString *deviceInformationString = [[NSMutableAttributedString alloc]
                                                           initWithString:[NSBundle mxk_localizedStringForKey:@"device_details_title"]
                                                           attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                        NSFontAttributeName: [UIFont boldSystemFontOfSize:15]}];
            [deviceInformationString appendAttributedString:[MXKDeviceView verticalWhitespace]];
            
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                      initWithString:[NSBundle mxk_localizedStringForKey:@"device_details_name"]
                                                      attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                   NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                             initWithString:device.displayName.length ? device.displayName : @""
                                                             attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                          NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
            [deviceInformationString appendAttributedString:[MXKDeviceView verticalWhitespace]];
            
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                      initWithString:[NSBundle mxk_localizedStringForKey:@"device_details_identifier"]                                                      attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                   NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                      initWithString:device.deviceId
                                                      attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                   NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
            [deviceInformationString appendAttributedString:[MXKDeviceView verticalWhitespace]];
            
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                      initWithString:[NSBundle mxk_localizedStringForKey:@"device_details_last_seen"]
                                                      attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                   NSFontAttributeName: [UIFont boldSystemFontOfSize:14]}]];
            
            NSDate *lastSeenDate = [NSDate dateWithTimeIntervalSince1970:device.lastSeenTs/1000];
            
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setLocale:[[NSLocale alloc] initWithLocaleIdentifier:[[[NSBundle mainBundle] preferredLocalizations] objectAtIndex:0]]];
            [dateFormatter setDateStyle:NSDateFormatterShortStyle];
            [dateFormatter setTimeStyle:NSDateFormatterShortStyle];
            [dateFormatter setFormatterBehavior:NSDateFormatterBehavior10_4];
            
            NSString *lastSeen = [NSString stringWithFormat:[NSBundle mxk_localizedStringForKey:@"device_details_last_seen_format"], device.lastSeenIp, [dateFormatter stringFromDate:lastSeenDate]];
            
            [deviceInformationString appendAttributedString:[[NSMutableAttributedString alloc]
                                                      initWithString:lastSeen
                                                      attributes:@{NSForegroundColorAttributeName : _defaultTextColor,
                                                                   NSFontAttributeName: [UIFont systemFontOfSize:14]}]];
            [deviceInformationString appendAttributedString:[MXKDeviceView verticalWhitespace]];
            
            self.textView.attributedText = deviceInformationString;
        }
        else
        {
            _textView.text = nil;
        }
        
        // Hide potential activity indicator
        [_activityIndicator stopAnimating];
    }
    
    return self;
}

- (void)dealloc
{
    mxDevice = nil;
    mxSession = nil;
}

+ (NSAttributedString *)verticalWhitespace
{
    if (verticalWhitespace == nil)
    {
        verticalWhitespace = [[NSAttributedString alloc] initWithString:@"\n\n" attributes:@{NSFontAttributeName: [UIFont systemFontOfSize:4]}];
    }
    return verticalWhitespace;
}

#pragma mark - Actions

- (IBAction)onBgViewTap:(UITapGestureRecognizer*)sender
{
    [self removeFromSuperviewDidUpdate:NO];
}

- (IBAction)onButtonPressed:(id)sender
{
    if (sender == _cancelButton)
    {
        [self removeFromSuperviewDidUpdate:NO];
    }
    else if (sender == _renameButton)
    {
        [self renameDevice];
    }
    else if (sender == _deleteButton)
    {
        [self deleteDevice];
    }
}

#pragma mark -

- (void)renameDevice
{
    if (!self.delegate)
    {
        // Ignore
        NSLog(@"[MXKDeviceView] Rename device failed, delegate is missing");
        return;
    }
    
    [currentAlert dismiss:NO];
    
    __weak typeof(self) weakSelf = self;
    
    // Prompt the user to enter a device name.
    currentAlert = [[MXKAlert alloc] initWithTitle:nil message:[NSBundle mxk_localizedStringForKey:@"device_details_rename_prompt_message"] style:MXKAlertStyleAlert];
    
    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
        
        textField.secureTextEntry = NO;
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDefault;
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            textField.text = self->mxDevice.displayName;
        }
    }];
    
    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
        
        if (weakSelf)
        {
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
        }
        
    }];
    
    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
        
        if (weakSelf)
        {
            UITextField *textField = [alert textFieldAtIndex:0];
            
            typeof(self) self = weakSelf;
            self->currentAlert = nil;
            
            [self.activityIndicator startAnimating];
            
            self->mxCurrentOperation = [self->mxSession.matrixRestClient setDeviceName:textField.text forDeviceId:self->mxDevice.deviceId success:^{
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    
                    self->mxCurrentOperation = nil;
                    [self.activityIndicator stopAnimating];
                    
                    [self removeFromSuperviewDidUpdate:YES];
                }
                
            } failure:^(NSError *error) {
                
                // Notify MatrixKit user
                [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    
                    self->mxCurrentOperation = nil;
                    
                    NSLog(@"[MXKDeviceView] Rename device (%@) failed", self->mxDevice.deviceId);
                    
                    [self.activityIndicator stopAnimating];
                    
                    [self removeFromSuperviewDidUpdate:NO];
                }
                
            }];
        }
    }];
    
    [self.delegate deviceView:self presentMXKAlert:currentAlert];
}

- (void)deleteDevice
{
    if (!self.delegate)
    {
        // Ignore
        NSLog(@"[MXKDeviceView] Delete device failed, delegate is missing");
        return;
    }
    
    // Get an authentication session to prepare device deletion
    [self.activityIndicator startAnimating];
    
    mxCurrentOperation = [mxSession.matrixRestClient getSessionToDeleteDeviceByDeviceId:mxDevice.deviceId success:^(MXAuthenticationSession *authSession) {
        
        mxCurrentOperation = nil;

        // Check whether the password based type is supported
        BOOL isPasswordBasedTypeSupported = NO;
        for (MXLoginFlow *loginFlow in authSession.flows)
        {
            if ([loginFlow.type isEqualToString:kMXLoginFlowTypePassword] || [loginFlow.stages indexOfObject:kMXLoginFlowTypePassword] != NSNotFound)
            {
                isPasswordBasedTypeSupported = YES;
                break;
            }
        }
        
        if (isPasswordBasedTypeSupported && authSession.session)
        {
            // Prompt for a password
            [currentAlert dismiss:NO];
            
            __weak typeof(self) weakSelf = self;
            
            // Prompt the user to enter a device name.
            currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"device_details_delete_prompt_title"] message:[NSBundle mxk_localizedStringForKey:@"device_details_delete_prompt_message"] style:MXKAlertStyleAlert];
            
            [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
                
                textField.secureTextEntry = YES;
                textField.placeholder = nil;
                textField.keyboardType = UIKeyboardTypeDefault;
            }];
            
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"cancel"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                
                if (weakSelf)
                {
                    typeof(self) self = weakSelf;
                    self->currentAlert = nil;
                    
                    [self.activityIndicator stopAnimating];
                }
                
            }];
            
            [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"submit"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                
                if (weakSelf)
                {
                    UITextField *textField = [alert textFieldAtIndex:0];
                    
                    typeof(self) self = weakSelf;
                    self->currentAlert = nil;
                    
                    NSString *userId = self->mxSession.myUser.userId;
                    NSDictionary *authParams;
                    
                    // Sanity check
                    if (userId)
                    {
                        authParams = @{@"session":authSession.session,
                                       @"user": userId,
                                       @"password": textField.text,
                                       @"type": kMXLoginFlowTypePassword};

                    }
                    
                    self->mxCurrentOperation = [self->mxSession.matrixRestClient deleteDeviceByDeviceId:self->mxDevice.deviceId authParams:authParams success:^{
                        
                        if (weakSelf)
                        {
                            typeof(self) self = weakSelf;
                            
                            self->mxCurrentOperation = nil;
                            [self.activityIndicator stopAnimating];
                            
                            [self removeFromSuperviewDidUpdate:YES];
                        }
                        
                    } failure:^(NSError *error) {
                        
                        // Notify MatrixKit user
                        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                        
                        if (weakSelf)
                        {
                            typeof(self) self = weakSelf;
                            
                            self->mxCurrentOperation = nil;
                            
                            NSLog(@"[MXKDeviceView] Delete device (%@) failed", self->mxDevice.deviceId);
                            
                            [self.activityIndicator stopAnimating];
                            
                            [self removeFromSuperviewDidUpdate:NO];
                        }
                        
                    }];
                }
            }];
            
            [self.delegate deviceView:self presentMXKAlert:currentAlert];
        }
        else
        {
            NSLog(@"[MXKDeviceView] Delete device (%@) failed, auth session flow type is not supported", mxDevice.deviceId);
            [self.activityIndicator stopAnimating];
        }
        
    } failure:^(NSError *error) {
        
        mxCurrentOperation = nil;
        
        NSLog(@"[MXKDeviceView] Delete device (%@) failed, unable to get auth session", mxDevice.deviceId);
        [self.activityIndicator stopAnimating];
        
        // Notify MatrixKit user
        [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
    }];
}

@end
