/*
 Copyright 2015 OpenMarket Ltd
 
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

#import "MXKAlert.h"

#import "UIApplication+MatrixSDK.h"

#import <objc/runtime.h>

@interface MXKAlert()
{
    UIViewController* parentViewController;
    NSMutableArray *actions; // use only for iOS < 8
}

@property(nonatomic, strong) id alert; // alert is kind of UIAlertController for IOS 8 and later, in other cases it's kind of UIAlertView or UIActionSheet.
@end

@implementation MXKAlert

- (void)dealloc
{
    // iOS < 8
    if ([_alert isKindOfClass:[UIActionSheet class]] || [_alert isKindOfClass:[UIAlertView class]])
    {
        // Dismiss here AlertView or ActionSheet (if any) because its delegate is released
        [self dismiss:NO];
    }
    
    _alert = nil;
    parentViewController = nil;
    actions = nil;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message style:(MXKAlertStyle)style
{
    if (self = [super init])
    {
        // Using only UIAlertController for App Extensions, as the other options are unavailable for them
#ifdef MXK_APP_EXTENSIONS
        _alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:(UIAlertControllerStyle)style];
#else
        // Check iOS version
        if ([[[UIDevice currentDevice] systemVersion] floatValue] >= 8)
        {
            _alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:(UIAlertControllerStyle)style];
        }
        else
        {
            // Use legacy objects
            if (style == MXKAlertStyleActionSheet)
            {
                _alert = [[UIActionSheet alloc] initWithTitle:title delegate:self cancelButtonTitle:nil destructiveButtonTitle:nil otherButtonTitles:nil];
            }
            else
            {
                _alert = [[UIAlertView alloc] initWithTitle:title message:message delegate:self cancelButtonTitle:nil otherButtonTitles:nil];
            }
            
            self.cancelButtonIndex = -1;
        }
#endif
    }
    return self;
}


- (NSInteger)addActionWithTitle:(NSString *)title style:(MXKAlertActionStyle)style handler:(blockMXKAlert_onClick)handler
{
    NSInteger index = 0;
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        index = [(UIAlertController *)_alert actions].count;
        
        __weak typeof(self) weakSelf = self;
        UIAlertAction* action = [UIAlertAction actionWithTitle:title
                                                         style:(UIAlertActionStyle)style
                                                       handler:^(UIAlertAction * action) {
                                                           
                                                           if (handler)
                                                           {
                                                               handler(weakSelf);
                                                           }
                                                           
                                                       }];
        
        if (_mxkAccessibilityIdentifier)
        {
            action.accessibilityLabel = [NSString stringWithFormat:@"%@Action%@", _mxkAccessibilityIdentifier, title];
        }
        
        [(UIAlertController *)_alert addAction:action];
    }
    else if ([_alert isKindOfClass:[UIActionSheet class]])
    {
        if (actions == nil)
        {
            actions = [NSMutableArray array];
        }
        index = [(UIActionSheet *)_alert addButtonWithTitle:title];
        if (handler)
        {
            [actions addObject:handler];
        }
        else
        {
            [actions addObject:[NSNull null]];
        }
    }
    else if ([_alert isKindOfClass:[UIAlertView class]])
    {
        if (actions == nil)
        {
            actions = [NSMutableArray array];
        }
        index = [(UIAlertView *)_alert addButtonWithTitle:title];
        if (handler)
        {
            [actions addObject:handler];
        }
        else
        {
            [actions addObject:[NSNull null]];
        }
    }
    return index;
}

- (void)setMxkAccessibilityIdentifier:(NSString *)mxkAccessibilityIdentifier
{
    _mxkAccessibilityIdentifier = mxkAccessibilityIdentifier;
    
    // Consider only iOS >= 8.0
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        UIAlertController *alertController = (UIAlertController *)_alert;
        
        alertController.view.accessibilityIdentifier = mxkAccessibilityIdentifier;
        
        for (UIAlertAction *action in alertController.actions)
        {
            action.accessibilityLabel = [NSString stringWithFormat:@"%@Action%@", mxkAccessibilityIdentifier, action.title];
        }
        
        NSArray *textFieldArray = alertController.textFields;
        for (NSUInteger index = 0; index < textFieldArray.count; index++)
        {
            UITextField *textField = textFieldArray[index];
            textField.accessibilityIdentifier = [NSString stringWithFormat:@"%@TextField%tu", mxkAccessibilityIdentifier, index];
        }
    }
}

- (void)addTextFieldWithConfigurationHandler:(blockMXKAlert_textFieldHandler)configurationHandler
{
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        UIAlertController *alertController = (UIAlertController *)_alert;

        [alertController addTextFieldWithConfigurationHandler:configurationHandler];
        
        if (_mxkAccessibilityIdentifier)
        {
            // Define an accessibility id for each field.
            NSArray *textFieldArray = alertController.textFields;
            for (NSUInteger index = 0; index < textFieldArray.count; index++)
            {
                UITextField *textField = textFieldArray[index];
                textField.accessibilityIdentifier = [NSString stringWithFormat:@"%@TextField%tu", _mxkAccessibilityIdentifier, index];
            }
        }
    }
    else if ([_alert isKindOfClass:[UIAlertView class]])
    {
        UIAlertView *alertView = (UIAlertView *)_alert;
        // Check the current style
        if (alertView.alertViewStyle == UIAlertViewStyleDefault)
        {
            // Add the first text fields
            alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
            
            if (configurationHandler)
            {
                // Store the callback
                UITextField *textField = [alertView textFieldAtIndex:0];
                objc_setAssociatedObject(textField, "configurationHandler", [configurationHandler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        else if (alertView.alertViewStyle != UIAlertViewStyleLoginAndPasswordInput)
        {
            // Add a second text field
            alertView.alertViewStyle = UIAlertViewStyleLoginAndPasswordInput;
            
            if (configurationHandler)
            {
                // Store the callback
                UITextField *textField = [alertView textFieldAtIndex:1];
                objc_setAssociatedObject(textField, "configurationHandler", [configurationHandler copy], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        // CAUTION 1: only 2 text fields are supported for iOS < 8
        // CAUTION 2: alert style "UIAlertViewStyleSecureTextInput" is not supported, use the configurationHandler to handle secure text field
    }
}

- (void)showInViewController:(UIViewController*)viewController
{
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        if (viewController)
        {
            parentViewController = viewController;
            if (self.sourceView)
            {
                [_alert popoverPresentationController].sourceView = self.sourceView;
                [_alert popoverPresentationController].sourceRect = self.sourceView.bounds;
            }
            [viewController presentViewController:(UIAlertController *)_alert animated:YES completion:nil];
        }
    }
    else if ([_alert isKindOfClass:[UIActionSheet class]])
    {
        [(UIActionSheet *)_alert showInView:[[UIApplication mx_sharedApplication] keyWindow]];
    }
    else if ([_alert isKindOfClass:[UIAlertView class]])
    {
        UIAlertView *alertView = (UIAlertView *)_alert;
        if (alertView.alertViewStyle != UIAlertViewStyleDefault)
        {
            // Call here textField handlers
            UITextField *textField = [alertView textFieldAtIndex:0];
            blockMXKAlert_textFieldHandler configurationHandler = objc_getAssociatedObject(textField, "configurationHandler");
            if (configurationHandler)
            {
                configurationHandler (textField);
            }
            if (alertView.alertViewStyle == UIAlertViewStyleLoginAndPasswordInput)
            {
                textField = [alertView textFieldAtIndex:1];
                blockMXKAlert_textFieldHandler configurationHandler = objc_getAssociatedObject(textField, "configurationHandler");
                if (configurationHandler)
                {
                    configurationHandler (textField);
                }
            }
        }
        [alertView show];
    }
}

- (void)dismiss:(BOOL)animated
{
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        // only dismiss it if it is presented
        if (parentViewController.presentedViewController == _alert)
        {
            [parentViewController dismissViewControllerAnimated:animated completion:nil];
        }
    }
    else if ([_alert isKindOfClass:[UIActionSheet class]])
    {
        [((UIActionSheet *)_alert) dismissWithClickedButtonIndex:self.cancelButtonIndex animated:animated];
    }
    else if ([_alert isKindOfClass:[UIAlertView class]])
    {
        [((UIAlertView *)_alert) dismissWithClickedButtonIndex:self.cancelButtonIndex animated:animated];
    }
    _alert = nil;
}

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex{
    if ([_alert isKindOfClass:[UIAlertController class]])
    {
        return [((UIAlertController*)_alert).textFields objectAtIndex:textFieldIndex];
    }
    else if ([_alert isKindOfClass:[UIAlertView class]])
    {
        return [((UIAlertView*)_alert) textFieldAtIndex:textFieldIndex];
    }
    return nil;
}

#pragma mark - UIAlertViewDelegate (iOS < 8)

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // sanity check
    // the user could have forgotten to set the cancel button index
    if (buttonIndex < actions.count)
    {
        // Retrieve the callback
        blockMXKAlert_onClick block = [actions objectAtIndex:buttonIndex];
        if ([block isEqual:[NSNull null]] == NO)
        {
            // And call it
            dispatch_async(dispatch_get_main_queue(), ^{
                block(self);
            });
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            // Release alert reference
            _alert = nil;
        });
    }
}

#pragma mark - UIActionSheetDelegate (iOS < 8)

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    // sanity check
    // the user could have forgotten to set the cancel button index
    if (buttonIndex < actions.count)
    {
        // Retrieve the callback
        blockMXKAlert_onClick block = [actions objectAtIndex:buttonIndex];
        if ([block isEqual:[NSNull null]] == NO)
        {
            // And call it
            dispatch_async(dispatch_get_main_queue(), ^{
                block(self);
            });
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            // Release _alert reference
            _alert = nil;
        });
    }
}

@end
