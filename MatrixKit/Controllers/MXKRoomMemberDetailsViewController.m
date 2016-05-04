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

#import "MXKRoomMemberDetailsViewController.h"

#import "MXKTableViewCellWithButtons.h"

#import "MXKMediaManager.h"

#import "NSBundle+MatrixKit.h"

#import "MXKAppSettings.h"

#import "MXKConstants.h"

@interface MXKRoomMemberDetailsViewController ()
{
    id membersListener;
    
    // mask view while processing a request
    UIView* pendingRequestMask;
    UIActivityIndicatorView * pendingMaskSpinnerView;
    
    // Observe left rooms
    id leaveRoomNotificationObserver;
}

@end

@implementation MXKRoomMemberDetailsViewController
@synthesize mxRoom;

+ (UINib *)nib
{
    return [UINib nibWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

+ (instancetype)roomMemberDetailsViewController
{
    return [[[self class] alloc] initWithNibName:NSStringFromClass([MXKRoomMemberDetailsViewController class])
                                          bundle:[NSBundle bundleForClass:[MXKRoomMemberDetailsViewController class]]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Check whether the view controller has been pushed via storyboard
    if (!self.tableView)
    {
        // Instantiate view controller objects
        [[[self class] nib] instantiateWithOwner:self options:nil];
    }
    
    actionsArray = [[NSMutableArray alloc] init];
    
    // ignore useless update
    if (_mxRoomMember)
    {
        [self initObservers];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self initObservers];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    [self removeObservers];
}

- (void)destroy
{
    // close any pending actionsheet
    if (currentAlert)
    {
        [currentAlert dismiss:NO];
        currentAlert = nil;
    }
    
    [self removePendingActionMask];
    
    [self removeObservers];
    
    self.delegate = nil;
    
    [super destroy];
}

#pragma mark -

- (void)displayRoomMember:(MXRoomMember*)roomMember withMatrixRoom:(MXRoom*)room
{
    [self removeObservers];
    
    mxRoom = room;
    
    // Update matrix session associated to the view controller
    NSArray *mxSessions = self.mxSessions;
    for (MXSession *mxSession in mxSessions) {
        [self removeMatrixSession:mxSession];
    }
    [self addMatrixSession:room.mxSession];
    
    _mxRoomMember = roomMember;
    
    [self initObservers];
}

- (UIImage*)picturePlaceholder
{
    return [NSBundle mxk_imageFromMXKAssetsBundleWithName:@"default-profile"];
}

- (void)setEnableVoipCall:(BOOL)enableVoipCall
{
    if (_enableVoipCall != enableVoipCall)
    {
        _enableVoipCall = enableVoipCall;
        
        [self updateMemberInfo];
    }
}

- (IBAction)onActionButtonPressed:(id)sender
{
    if ([sender isKindOfClass:[UIButton class]])
    {
        // Check whether an action is already in progress
        if ([self hasPendingAction])
        {
            return;
        }
        
        UIButton *button = (UIButton*)sender;
        
        switch (button.tag)
        {
            case MXKRoomMemberDetailsActionInvite:
            {
                [self addPendingActionMask];
                [mxRoom inviteUser:_mxRoomMember.userId
                           success:^{
                               
                               [self removePendingActionMask];
                               
                           } failure:^(NSError *error) {
                               
                               [self removePendingActionMask];
                               NSLog(@"[MXKRoomMemberDetailsVC] Invite %@ failed: %@", _mxRoomMember.userId, error);
                               // Notify MatrixKit user
                               [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                               
                           }];
                break;
            }
            case MXKRoomMemberDetailsActionLeave:
            {
                [self addPendingActionMask];
                [self.mxRoom leave:^{
                    
                    [self removePendingActionMask];
                    [self withdrawViewControllerAnimated:YES completion:nil];
                    
                } failure:^(NSError *error) {
                    
                    [self removePendingActionMask];
                    NSLog(@"[MXKRoomMemberDetailsVC] Leave room %@ failed: %@", mxRoom.state.roomId, error);
                    // Notify MatrixKit user
                    [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                    
                }];
                break;
            }
            case MXKRoomMemberDetailsActionKick:
            {
                [self addPendingActionMask];
                [mxRoom kickUser:_mxRoomMember.userId
                          reason:nil
                         success:^{
                             
                             [self removePendingActionMask];
                             // Pop/Dismiss the current view controller if the left members are hidden
                             if (![[MXKAppSettings standardAppSettings] showLeftMembersInRoomMemberList])
                             {
                                 [self withdrawViewControllerAnimated:YES completion:nil];
                             }
                             
                         } failure:^(NSError *error) {
                             
                             [self removePendingActionMask];
                             NSLog(@"[MXKRoomMemberDetailsVC] Kick %@ failed: %@", _mxRoomMember.userId, error);
                             // Notify MatrixKit user
                             [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                             
                         }];
                break;
            }
            case MXKRoomMemberDetailsActionBan:
            {
                [self addPendingActionMask];
                [mxRoom banUser:_mxRoomMember.userId
                         reason:nil
                        success:^{
                            
                            [self removePendingActionMask];
                            
                        } failure:^(NSError *error) {
                            
                            [self removePendingActionMask];
                            NSLog(@"[MXKRoomMemberDetailsVC] Ban %@ failed: %@", _mxRoomMember.userId, error);
                            // Notify MatrixKit user
                            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                            
                        }];
                break;
            }
            case MXKRoomMemberDetailsActionUnban:
            {
                [self addPendingActionMask];
                [mxRoom unbanUser:_mxRoomMember.userId
                          success:^{
                              
                              [self removePendingActionMask];
                              
                          } failure:^(NSError *error) {
                              
                              [self removePendingActionMask];
                              NSLog(@"[MXKRoomMemberDetailsVC] Unban %@ failed: %@", _mxRoomMember.userId, error);
                              // Notify MatrixKit user
                              [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                              
                          }];
                break;
            }
            case MXKRoomMemberDetailsActionIgnore:
            {
                // Prompt user to ignore content from this user
                __weak __typeof(self) weakSelf = self;
                [currentAlert dismiss:NO];
                currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"room_member_ignore_prompt"]  message:nil style:MXKAlertStyleAlert];
                
                [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"yes"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                    
                    // Add the user to the blacklist: ignored users
                    [strongSelf addPendingActionMask];
                    [strongSelf.mainSession ignoreUser:strongSelf.mxRoomMember.userId
                                         success:^{
                                             
                                             [strongSelf removePendingActionMask];
                                             
                                         } failure:^(NSError *error) {
                                             
                                             [strongSelf removePendingActionMask];
                                             NSLog(@"[MXKRoomMemberDetailsVC] Ignore %@ failed: %@", strongSelf.mxRoomMember.userId, error);
                                             
                                             // Notify MatrixKit user
                                             [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                             
                                         }];
                    
                }];
                
                currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"no"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert) {
                    
                    __strong __typeof(weakSelf)strongSelf = weakSelf;
                    strongSelf->currentAlert = nil;
                }];
                
                [currentAlert showInViewController:self];
                break;
            }
            case MXKRoomMemberDetailsActionUnignore:
            {
                // FIXME Remove the member from the ignored user list.
                break;
            }
            case MXKRoomMemberDetailsActionSetDefaultPowerLevel:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetModerator:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetAdmin:
            {
                break;
            }
            case MXKRoomMemberDetailsActionSetCustomPowerLevel:
            {
                [self updateUserPowerLevel];
                break;
            }
            case MXKRoomMemberDetailsActionStartChat:
            {
                if (self.delegate)
                {
                    [self addPendingActionMask];
                    
                    [self.delegate roomMemberDetailsViewController:self startChatWithMemberId:_mxRoomMember.userId completion:^{
                        
                        [self removePendingActionMask];
                    }];
                }
                break;
            }
            case MXKRoomMemberDetailsActionStartVoiceCall:
            case MXKRoomMemberDetailsActionStartVideoCall:
            {
                BOOL isVideoCall = (button.tag == MXKRoomMemberDetailsActionStartVideoCall);
                
                if (self.delegate && [self.delegate respondsToSelector:@selector(roomMemberDetailsViewController:placeVoipCallWithMemberId:andVideo:)])
                {
                    [self addPendingActionMask];
                    
                    [self.delegate roomMemberDetailsViewController:self placeVoipCallWithMemberId:_mxRoomMember.userId andVideo:isVideoCall];
                    
                    [self removePendingActionMask];
                }
                else
                {
                    [self addPendingActionMask];
                    
                    MXRoom* oneToOneRoom = [self.mainSession privateOneToOneRoomWithUserId:_mxRoomMember.userId];
                    
                    // Place the call directly if the room exists
                    if (oneToOneRoom)
                    {
                        [self.mainSession.callManager placeCallInRoom:oneToOneRoom.state.roomId withVideo:isVideoCall];
                        [self removePendingActionMask];
                    }
                    else
                    {
                        // Create a new room
                        [self.mainSession createRoom:nil
                                          visibility:kMXRoomVisibilityPrivate
                                           roomAlias:nil
                                               topic:nil
                                             success:^(MXRoom *room) {
                                                 
                                                 // Add the user
                                                 [room inviteUser:_mxRoomMember.userId success:^{
                                                     
                                                     // Delay the call in order to be sure that the room is ready
                                                     dispatch_async(dispatch_get_main_queue(), ^{
                                                         [self.mainSession.callManager placeCallInRoom:room.state.roomId withVideo:isVideoCall];
                                                         [self removePendingActionMask];
                                                     });
                                                     
                                                 } failure:^(NSError *error) {
                                                     
                                                     NSLog(@"[MXKRoomMemberDetailsVC] %@ invitation failed (roomId: %@): %@", _mxRoomMember.userId, room.state.roomId, error);
                                                     [self removePendingActionMask];
                                                     // Notify MatrixKit user
                                                     [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                                     
                                                 }];
                                                 
                                             } failure:^(NSError *error) {
                                                 
                                                 NSLog(@"[MXKRoomMemberDetailsVC] Create room failed: %@", error);
                                                 [self removePendingActionMask];
                                                 // Notify MatrixKit user
                                                 [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
                                                 
                                             }];
                    }
                }
                break;
            }
            default:
                break;
        }
    }
}

#pragma mark - Internals

- (void)initObservers
{
    // Remove any pending observers
    [self removeObservers];
    
    if (mxRoom)
    {
        // Observe room's members update
        NSArray *mxMembersEvents = @[kMXEventTypeStringRoomMember, kMXEventTypeStringRoomPowerLevels];
        membersListener = [mxRoom.liveTimeline listenToEventsOfTypes:mxMembersEvents onEvent:^(MXEvent *event, MXTimelineDirection direction, id customObject) {
            
            // consider only live event
            if (direction == MXTimelineDirectionForwards)
            {
                // Hide potential action sheet
                if (currentAlert)
                {
                    [currentAlert dismiss:NO];
                    currentAlert = nil;
                }
                
                MXRoomMember* nextRoomMember = nil;
                
                // get the updated memmber
                NSArray* membersList = [self.mxRoom.state members];
                for (MXRoomMember* member in membersList)
                {
                    if ([member.userId isEqualToString:_mxRoomMember.userId])
                    {
                        nextRoomMember = member;
                        break;
                    }
                }
                
                // does the member still exist ?
                if (nextRoomMember)
                {
                    // Refresh member
                    _mxRoomMember = nextRoomMember;
                    [self updateMemberInfo];
                }
                else
                {
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
            
        }];
        
        // Observe kMXSessionWillLeaveRoomNotification to be notified if the user leaves the current room.
        leaveRoomNotificationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:kMXSessionWillLeaveRoomNotification object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *notif) {
            
            // Check whether the user will leave the room related to the displayed member
            if (notif.object == self.mainSession)
            {
                NSString *roomId = notif.userInfo[kMXSessionNotificationRoomIdKey];
                if (roomId && [roomId isEqualToString:mxRoom.state.roomId])
                {
                    // We must remove the current view controller.
                    [self withdrawViewControllerAnimated:YES completion:nil];
                }
            }
        }];
    }
    
    [self updateMemberInfo];
}

- (void)removeObservers
{
    if (leaveRoomNotificationObserver)
    {
        [[NSNotificationCenter defaultCenter] removeObserver:leaveRoomNotificationObserver];
        leaveRoomNotificationObserver = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    if (membersListener && mxRoom)
    {
        [mxRoom.liveTimeline removeListener:membersListener];
        membersListener = nil;
    }
}

- (void)updateMemberInfo
{
    self.title = _mxRoomMember.displayname ? _mxRoomMember.displayname : _mxRoomMember.userId;
    
    // set the thumbnail info
    self.memberThumbnail.contentMode = UIViewContentModeScaleAspectFill;
    self.memberThumbnail.backgroundColor = [UIColor clearColor];
    [self.memberThumbnail.layer setCornerRadius:self.memberThumbnail.frame.size.width / 2];
    [self.memberThumbnail setClipsToBounds:YES];
    
    NSString *thumbnailURL = nil;
    if (_mxRoomMember.avatarUrl)
    {
        // Suppose this url is a matrix content uri, we use SDK to get the well adapted thumbnail from server
        thumbnailURL = [self.mainSession.matrixRestClient urlOfContentThumbnail:_mxRoomMember.avatarUrl toFitViewSize:self.memberThumbnail.frame.size withMethod:MXThumbnailingMethodCrop];
    }
    
    self.memberThumbnail.mediaFolder = kMXKMediaManagerAvatarThumbnailFolder;
    self.memberThumbnail.enableInMemoryCache = YES;
    [self.memberThumbnail setImageURL:thumbnailURL withType:nil andImageOrientation:UIImageOrientationUp previewImage:self.picturePlaceholder];
    
    self.roomMemberMatrixInfo.text = _mxRoomMember.userId;
    
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Check user's power level before allowing an action (kick, ban, ...)
    MXRoomPowerLevels *powerLevels = [mxRoom.state powerLevels];
    NSInteger memberPowerLevel = [powerLevels powerLevelOfUserWithUserID:_mxRoomMember.userId];
    NSInteger oneSelfPowerLevel = [powerLevels powerLevelOfUserWithUserID:self.mainSession.myUser.userId];
    
    [actionsArray removeAllObjects];
    
    // Consider the case of the user himself
    if ([_mxRoomMember.userId isEqualToString:self.mainSession.myUser.userId])
    {
        [actionsArray addObject:@(MXKRoomMemberDetailsActionLeave)];
        
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels])
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionSetCustomPowerLevel)];
        }
    }
    else if (_mxRoomMember)
    {
        if (_enableVoipCall)
        {
            // Offer voip call options
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartVoiceCall)];
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartVideoCall)];
        }
        
        // Consider membership of the selected member
        switch (_mxRoomMember.membership)
        {
            case MXMembershipInvite:
            case MXMembershipJoin:
            {
                // Check conditions to be able to kick someone
                if (oneSelfPowerLevel >= [powerLevels kick] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionKick)];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionBan)];
                }
                
                // Check whether the option Ignore may be presented
                if (_mxRoomMember.membership == MXMembershipJoin)
                {
                    //FIXME: is he already ignored ?
//                    if ()
                    {
                        [actionsArray addObject:@(MXKRoomMemberDetailsActionIgnore)];
                    }
//                    else
//                    {
//                        [actionsArray addObject:@(MXKRoomMemberDetailsActionUnignore)];
//                    }
                }
                break;
            }
            case MXMembershipLeave:
            {
                // Check conditions to be able to invite someone
                if (oneSelfPowerLevel >= [powerLevels invite])
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionInvite)];
                }
                // Check conditions to be able to ban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionBan)];
                }
                break;
            }
            case MXMembershipBan:
            {
                // Check conditions to be able to unban someone
                if (oneSelfPowerLevel >= [powerLevels ban] && oneSelfPowerLevel > memberPowerLevel)
                {
                    [actionsArray addObject:@(MXKRoomMemberDetailsActionUnban)];
                }
                break;
            }
            default:
            {
                break;
            }
        }
        
        // update power level
        if (oneSelfPowerLevel >= [powerLevels minimumPowerLevelForSendingEventAsStateEvent:kMXEventTypeStringRoomPowerLevels] && oneSelfPowerLevel > memberPowerLevel)
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionSetCustomPowerLevel)];
        }
        
        // offer to start a new chat only if the room is not a 1:1 room with this user
        // it does not make sense : it would open the same room
        MXRoom* room = [self.mainSession privateOneToOneRoomWithUserId:_mxRoomMember.userId];
        if (!room || (![room.state.roomId isEqualToString:mxRoom.state.roomId]))
        {
            [actionsArray addObject:@(MXKRoomMemberDetailsActionStartChat)];
        }
    }
    
    return (actionsArray.count + 1) / 2;
}

- (NSString*)actionButtonTitle:(MXKRoomMemberDetailsAction)action
{
    NSString *title;
    
    switch (action)
    {
        case MXKRoomMemberDetailsActionInvite:
            title = [NSBundle mxk_localizedStringForKey:@"invite"];
            break;
        case MXKRoomMemberDetailsActionLeave:
            title = [NSBundle mxk_localizedStringForKey:@"leave"];
            break;
        case MXKRoomMemberDetailsActionKick:
            title = [NSBundle mxk_localizedStringForKey:@"kick"];
            break;
        case MXKRoomMemberDetailsActionBan:
            title = [NSBundle mxk_localizedStringForKey:@"ban"];
            break;
        case MXKRoomMemberDetailsActionUnban:
            title = [NSBundle mxk_localizedStringForKey:@"unban"];
            break;
        case MXKRoomMemberDetailsActionIgnore:
            title = [NSBundle mxk_localizedStringForKey:@"ignore"];
            break;
        case MXKRoomMemberDetailsActionUnignore:
            title = [NSBundle mxk_localizedStringForKey:@"unignore"];
            break;
        case MXKRoomMemberDetailsActionSetDefaultPowerLevel:
            title = [NSBundle mxk_localizedStringForKey:@"set_default_power_level"];
            break;
        case MXKRoomMemberDetailsActionSetModerator:
            title = [NSBundle mxk_localizedStringForKey:@"set_moderator"];
            break;
        case MXKRoomMemberDetailsActionSetAdmin:
            title = [NSBundle mxk_localizedStringForKey:@"set_admin"];
            break;
        case MXKRoomMemberDetailsActionSetCustomPowerLevel:
            title = [NSBundle mxk_localizedStringForKey:@"set_power_level"];
            break;
        case MXKRoomMemberDetailsActionStartChat:
            title = [NSBundle mxk_localizedStringForKey:@"start_chat"];
            break;
        case MXKRoomMemberDetailsActionStartVoiceCall:
            title = [NSBundle mxk_localizedStringForKey:@"start_voice_call"];
            break;
        case MXKRoomMemberDetailsActionStartVideoCall:
            title = [NSBundle mxk_localizedStringForKey:@"start_video_call"];
            break;
        default:
            break;
    }
    
    return title;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (self.tableView == tableView)
    {
        NSInteger row = indexPath.row;
        
        MXKTableViewCellWithButtons *cell = [tableView dequeueReusableCellWithIdentifier:[MXKTableViewCellWithButtons defaultReuseIdentifier]];
        if (!cell)
        {
            cell = [[MXKTableViewCellWithButtons alloc] init];
        }
        
        cell.mxkButtonNumber = 2;
        NSArray *buttons = cell.mxkButtons;
        NSInteger index = row * 2;
        NSString *text = nil;
        for (UIButton *button in buttons)
        {
            NSNumber *actionNumber;
            if (index < actionsArray.count)
            {
                actionNumber = [actionsArray objectAtIndex:index];
            }
            
            text = (actionNumber ? [self actionButtonTitle:actionNumber.unsignedIntegerValue] : nil);
            
            button.hidden = (text.length == 0);
            
            button.layer.borderColor = button.tintColor.CGColor;
            button.layer.borderWidth = 1;
            button.layer.cornerRadius = 5;
            
            [button setTitle:text forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateHighlighted];
            
            [button addTarget:self action:@selector(onActionButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            
            button.tag = (actionNumber ? actionNumber.unsignedIntegerValue : -1);
            
            index ++;
        }
        
        return cell;
    }
    
    return nil;
}


#pragma mark - button management

- (BOOL)hasPendingAction
{
    return nil != pendingMaskSpinnerView;
}

- (void)addPendingActionMask
{
    // add a spinner above the tableview to avoid that the user tap on any other button
    pendingMaskSpinnerView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
    pendingMaskSpinnerView.backgroundColor = [UIColor colorWithRed:0.5 green:0.5 blue:0.5 alpha:0.5];
    pendingMaskSpinnerView.frame = self.tableView.frame;
    pendingMaskSpinnerView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleTopMargin;
    
    // append it
    [self.tableView.superview addSubview:pendingMaskSpinnerView];
    
    // animate it
    [pendingMaskSpinnerView startAnimating];
}

- (void)removePendingActionMask
{
    if (pendingMaskSpinnerView)
    {
        [pendingMaskSpinnerView removeFromSuperview];
        pendingMaskSpinnerView = nil;
        [self.tableView reloadData];
    }
}

- (void)setPowerLevel:(NSInteger)value
{
    NSInteger currentPowerLevel = [self.mxRoom.state.powerLevels powerLevelOfUserWithUserID:_mxRoomMember.userId];
    
    // check if the power level has not yet been set to 0
    if (value != currentPowerLevel)
    {
        __weak typeof(self) weakSelf = self;
        
        [self addPendingActionMask];
        
        // Reset user power level
        [self.mxRoom setPowerLevelOfUserWithUserID:_mxRoomMember.userId powerLevel:value success:^{
            
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf removePendingActionMask];
            
        } failure:^(NSError *error) {
            
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            [strongSelf removePendingActionMask];
            NSLog(@"[MXKRoomMemberDetailsVC] Set user power (%@) failed: %@", strongSelf.mxRoomMember.userId, error);
            
            // Notify MatrixKit user
            [[NSNotificationCenter defaultCenter] postNotificationName:kMXKErrorNotification object:error];
            
        }];
    }
}

- (void)updateUserPowerLevel
{
    __weak typeof(self) weakSelf = self;
    
    // Ask for the power level to set
    [currentAlert dismiss:NO];
    currentAlert = [[MXKAlert alloc] initWithTitle:[NSBundle mxk_localizedStringForKey:@"power_level"]  message:nil style:MXKAlertStyleAlert];
    
    if (![self.mainSession.myUser.userId isEqualToString:_mxRoomMember.userId])
    {
        currentAlert.cancelButtonIndex = [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"reset_to_default"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
        {
            __strong __typeof(weakSelf)strongSelf = weakSelf;
            strongSelf->currentAlert = nil;
            
            [strongSelf setPowerLevel:strongSelf.mxRoom.state.powerLevels.usersDefault];
        }];
    }
    [currentAlert addTextFieldWithConfigurationHandler:^(UITextField *textField)
    {
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        
        textField.secureTextEntry = NO;
        textField.text = [NSString stringWithFormat:@"%zd", [strongSelf.mxRoom.state.powerLevels powerLevelOfUserWithUserID:strongSelf.mxRoomMember.userId]];
        textField.placeholder = nil;
        textField.keyboardType = UIKeyboardTypeDecimalPad;
    }];
    [currentAlert addActionWithTitle:[NSBundle mxk_localizedStringForKey:@"ok"] style:MXKAlertActionStyleDefault handler:^(MXKAlert *alert)
    {
        UITextField *textField = [alert textFieldAtIndex:0];
        
        __strong __typeof(weakSelf)strongSelf = weakSelf;
        strongSelf->currentAlert = nil;
        
        if (textField.text.length > 0)
        {
            [strongSelf setPowerLevel:[textField.text integerValue]];
        }
    }];
    [currentAlert showInViewController:self];
}

@end
