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
}

@property (nonatomic, strong) UIAlertController *alert; // alert is kind of UIAlertController for IOS 8 and later, in other cases it's kind of UIAlertView or UIActionSheet.
@end

@implementation MXKAlert

- (void)dealloc
{
    _alert = nil;
    parentViewController = nil;
}

- (id)initWithTitle:(NSString *)title message:(NSString *)message style:(MXKAlertStyle)style
{
    if (self = [super init])
    {
        _alert = [UIAlertController alertControllerWithTitle:title message:message preferredStyle:(UIAlertControllerStyle)style];
    }
    return self;
}


- (void)addActionWithTitle:(NSString *)title style:(MXKAlertActionStyle)style handler:(blockMXKAlert_onClick)handler
{
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
    
    [_alert addAction:action];
}

- (void)setMxkAccessibilityIdentifier:(NSString *)mxkAccessibilityIdentifier
{
    _mxkAccessibilityIdentifier = mxkAccessibilityIdentifier;
    
    _alert.view.accessibilityIdentifier = mxkAccessibilityIdentifier;
    
    for (UIAlertAction *action in _alert.actions)
    {
        action.accessibilityLabel = [NSString stringWithFormat:@"%@Action%@", mxkAccessibilityIdentifier, action.title];
    }
    
    NSArray *textFieldArray = _alert.textFields;
    for (NSUInteger index = 0; index < textFieldArray.count; index++)
    {
        UITextField *textField = textFieldArray[index];
        textField.accessibilityIdentifier = [NSString stringWithFormat:@"%@TextField%tu", mxkAccessibilityIdentifier, index];
    }
}

- (void)addTextFieldWithConfigurationHandler:(blockMXKAlert_textFieldHandler)configurationHandler
{
    [_alert addTextFieldWithConfigurationHandler:configurationHandler];
    
    if (_mxkAccessibilityIdentifier)
    {
        // Define an accessibility id for each field.
        NSArray *textFieldArray = _alert.textFields;
        for (NSUInteger index = 0; index < textFieldArray.count; index++)
        {
            UITextField *textField = textFieldArray[index];
            textField.accessibilityIdentifier = [NSString stringWithFormat:@"%@TextField%tu", _mxkAccessibilityIdentifier, index];
        }
    }
}

- (void)showInViewController:(UIViewController*)viewController
{
    if (viewController)
    {
        parentViewController = viewController;
        if (self.sourceView)
        {
            [_alert popoverPresentationController].sourceView = self.sourceView;
            [_alert popoverPresentationController].sourceRect = self.sourceView.bounds;
        }
        [viewController presentViewController:_alert animated:YES completion:nil];
    }
}

- (void)dismiss:(BOOL)animated
{
    // only dismiss it if it is presented
    if (parentViewController.presentedViewController == _alert)
    {
        [parentViewController dismissViewControllerAnimated:animated completion:nil];
    }
    _alert = nil;
}

- (UITextField *)textFieldAtIndex:(NSInteger)textFieldIndex
{
    return [_alert.textFields objectAtIndex:textFieldIndex];
}


@end
