//
//  SentegrityTAF_FirstTimeViewController.m
//  Sentegrity
//
//  Created by Ivo Leko on 27/07/16.
//  Copyright © 2016 Sentegrity. All rights reserved.
//

#import "ISHPermissionKit.h"
#import "Sentegrity_TrustFactor_Datasets.h"


#import "SentegrityTAF_FirstTimeViewController.h"
#import "SentegrityTAF_WelcomeViewController.h"
#import "SentegrityTAF_AskPermissionsViewController.h"
#import "SentegrityTAF_PasswordCreationViewController.h"
#import "SentegrityTAF_UnlockViewController.h"
#import "SentegrityTAF_TouchIDManager.h"
#import "SentegrityTAF_TouchIDPermissionViewController.h"
#import "SentegrityTAF_VocalFacialPermissionsViewController.h"

#import "JailBreakChecks.h"
#import "iOD.h"


typedef enum {
    CurrentStateUnknown = 0,
    CurrentStateWelcome,
    CurrentStateAskingPermissions,
    CurrentStatePasswordCreation,
    CurrentStateTouchIDCreation,
    CurrentStateVocalFacialCreation,
    CurrentStateUnlock,
} CurrentState;

@interface SentegrityTAF_FirstTimeViewController () <SentegrityTAF_basicProtocol>

@property (nonatomic, strong) SentegrityTAF_VocalFacialPermissionsViewController *vocalFacialPermissionViewController;
@property (strong, nonatomic) SentegrityTAF_TouchIDPermissionViewController *touchIDPermissionViewController;
@property (strong, nonatomic) SentegrityTAF_PasswordCreationViewController *passwordCreationViewController;
@property (strong, nonatomic) SentegrityTAF_AskPermissionsViewController *askPermissionsViewController;
@property (strong, nonatomic) SentegrityTAF_WelcomeViewController *welcomeViewController;
@property (nonatomic, strong) SentegrityTAF_UnlockViewController *unlockViewController;

@property (nonatomic, strong) NSData *masterKey;

@property (nonatomic, strong) UIViewController *currentViewController;

//helper for managing viewController's views
@property (weak, nonatomic) IBOutlet ILContainerView *containerView;

//current Sentegrity First time state
@property (nonatomic) CurrentState currentState;


@end

@implementation SentegrityTAF_FirstTimeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [self.containerView setCurrentViewController:self];
    
    //show welcome screen
    [self showWelcome];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}
- (void) setCurrentViewController:(UIViewController *)currentViewController {
    
    //show currentViewController on the screen
    [self.containerView setChildViewController:currentViewController];
    _currentViewController = currentViewController;
    
}

- (void)updateUIForNotification:(enum DAFUINotification)event {
    // We don't expect this VC to be active during a change-password
    // sequence. If this becomes a valid situation, fix this code to dismiss
    // this VC (see DAFSkelUnlockViewController).
    
    NSAssert( !(event == ChangePasswordCancelled && _result != nil), @"Unexpected ChangePasswordCancelled");
}

- (void) dismissSuccesfullyFinishedViewController:(UIViewController *) vc withInfo:(NSDictionary *)info {
    
    // Check if policy allows facial (disabled for app store approval)
    NSError *error2;
    Sentegrity_Policy *policy = [[Sentegrity_Policy_Parser sharedPolicy] getPolicy:&error2];
    
    //clear current state
    CurrentState lastCurrentState = _currentState;
    _currentState = CurrentStateUnknown;
    
    //after welcome screen, we need to show permission screen
    if (lastCurrentState == CurrentStateWelcome) {
        [self showAskingForPermissions];
    }
    
    //after permission screen, we need to show password creation screen
    else  if (lastCurrentState == CurrentStateAskingPermissions) {
        [self showPasswordCreationWithResult:self.result];
        
    }
    
    //after creation of password, show unlock screen or touchID if available
    else  if (lastCurrentState == CurrentStatePasswordCreation) {
        
        self.masterKey = info[@"masterKey"];
        
        NSNumber *passcodeStatus = [[Sentegrity_TrustFactor_Datasets sharedDatasets] getPassword];
        NSError *error;

        
        //if passcode is set
        if (passcodeStatus.integerValue == 1) {
            
            //check if touchID is avaialable, and fingerprint is set
            if ([[SentegrityTAF_TouchIDManager shared] checkIfTouchIDIsAvailableWithError:&error]) {
                //true
                [self showTouchIDWithResult:_result andMasterKey:self.masterKey];
            }
            else {
                // error code == -7 ("No fingers are enrolled with Touch ID.")
                // error code == -5 ("Passcode not set.")
                
                if (error.code == (-7)) {
                    //no fingers are enrolled, show TouchID and ask user to add fingerprint
                    [self showTouchIDWithResult:_result andMasterKey:self.masterKey];
                }
                else {
                    // no touchID support, continue
                    // If disabled show the unlock screen
                    if (policy.disableFacial.intValue==1) {
                        
                        [self showUnlockWithResult:self.result];
                    }
                    else{ // Show facial
                        
                        [self showVocalFacialWithResult:_result andMasterKey:self.masterKey];
                    }
                }
            }
        }
        
        else if (passcodeStatus.integerValue == 2) {
            
            // If disabled show the unlock screen
            if (policy.disableFacial.intValue==1) {
                
                [self showUnlockWithResult:self.result];
            }
            else{ // Show device passcode missing popup
                
                
                UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"Warning"
                                                                               message:@"A device-level passcode was not detected. This will result in increased authentication requirements. Would you like to add a passcode to the device?"
                                                                        preferredStyle:UIAlertControllerStyleAlert];
                
                UIAlertAction* cancelAction = [UIAlertAction actionWithTitle:@"No, Continue"
                                                                       style:UIAlertActionStyleDefault
                                                                     handler:^(UIAlertAction * action) {
                                                                         
                                                                         //set startup flag that user disabled TouchID
                                                                         NSError *error;
                                                                         Sentegrity_Startup *startup = [[Sentegrity_Startup_Store sharedStartupStore] getStartupStore:&error];
                                                                         
                                                                         
                                                                         if (!error) {
                                                                             [startup setTouchIDDisabledByUser:YES];
                                                                             [[Sentegrity_Startup_Store sharedStartupStore] setStartupStoreWithError:nil];
                                                                         }
                                                                         else {
                                                                             NSLog(@"ERROR: loading startup file");
                                                                         }
                                                                         
                                                                         // Continue to next step (Vocal Facial)
                                                                         // If disabled show the unlock screen
                                                                         if (policy.disableFacial.intValue==1) {
                                                                             
                                                                             [self showUnlockWithResult:self.result];
                                                                         }
                                                                         else{ // Show facial
                                                                             
                                                                             [self showVocalFacialWithResult:_result andMasterKey:self.masterKey];
                                                                         }
                                                                         
                                                                     }];
                
                UIAlertAction* settingsAction = [UIAlertAction actionWithTitle:@"Yes, Exit Setup"
                                                                         style:UIAlertActionStyleDefault
                                                                       handler:^(UIAlertAction * action) {
                                                                           //Force to crash
                                                                           [self performSelector:NSSelectorFromString(@"crashme:") withObject:nil afterDelay:1];
                                                                       }];
                
                [alert addAction:cancelAction];
                [alert addAction:settingsAction];
                
                [self presentViewController:alert animated:YES completion:nil];

            }
        }
        
        
        else /*if (passcodeStatus.integerValue == 0) */{
            //unknown state, continue to the next step
            // If disabled show the unlock screen
            if (policy.disableFacial.intValue==1) {
                
                [self showUnlockWithResult:self.result];
            }
            else{ // Show facial
                
                [self showVocalFacialWithResult:_result andMasterKey:self.masterKey];
            }

        }
    }
    
    //after touchID show vocal/facial enrollment screen
    else  if (lastCurrentState == CurrentStateTouchIDCreation) {
        
        
        // If disabled show the unlock screen
        if (policy.disableFacial.intValue==1) {
            
            [self showUnlockWithResult:self.result];
        }
        else{ // Show facial
            
             [self showVocalFacialWithResult:_result andMasterKey:self.masterKey];
        }
        
    }
    
    //after vocal/facial  show unlock screen
    else  if (lastCurrentState == CurrentStateVocalFacialCreation) {
        [self showUnlockWithResult:self.result];
    }

    //finished everything for first time run, proceed to DAF
    else {
        [self dismissViewControllerAnimated:NO completion: ^{
            self.result = nil;
        }];
    }
}



- (void) showWelcome {
    SentegrityTAF_WelcomeViewController *welcome = [[SentegrityTAF_WelcomeViewController alloc] init];
    welcome.delegate = self;
    
    //set new screen and state
    self.currentState = CurrentStateWelcome;
    self.welcomeViewController = welcome;
    self.currentViewController = welcome;
}

- (void) showAskingForPermissions {
    SentegrityTAF_AskPermissionsViewController *askingPermission = [[SentegrityTAF_AskPermissionsViewController alloc] init];
    askingPermission.delegate = self;
    askingPermission.permissions = self.applicationPermissions;
    askingPermission.activityDispatcher = self.activityDispatcher;
    
    //set new screen and state
    self.currentState = CurrentStateAskingPermissions;
    self.askPermissionsViewController = askingPermission;
    self.currentViewController = askingPermission;
}



- (void) showPasswordCreationWithResult: (DAFWaitableResult *)result {
    
    SentegrityTAF_PasswordCreationViewController *passwordCreationViewController;
    
    
    passwordCreationViewController = [[SentegrityTAF_PasswordCreationViewController alloc] initWithNibName:@"SentegrityTAF_PasswordCreationViewController" bundle:nil];
    passwordCreationViewController.delegate = self;
    passwordCreationViewController.result = self.result;
    
    //set new screen and state
    self.currentState = CurrentStatePasswordCreation;
    self.passwordCreationViewController = passwordCreationViewController;
    self.currentViewController = passwordCreationViewController;
}


- (void) showTouchIDWithResult: (DAFWaitableResult *)result andMasterKey: (NSData *) masterKey {
    
    SentegrityTAF_TouchIDPermissionViewController *touchIDPermissionVC = [[SentegrityTAF_TouchIDPermissionViewController alloc] init];

    touchIDPermissionVC.delegate = self;
    touchIDPermissionVC.result = self.result;
    touchIDPermissionVC.decryptedMasterKey = masterKey;
    
    //set new screen and state
    self.currentState = CurrentStateTouchIDCreation;
    self.touchIDPermissionViewController = touchIDPermissionVC;
    self.currentViewController = touchIDPermissionVC;
}


- (void) showVocalFacialWithResult: (DAFWaitableResult *)result andMasterKey: (NSData *) masterKey {
    
    SentegrityTAF_VocalFacialPermissionsViewController *vocalFacialPermissionViewController = [[SentegrityTAF_VocalFacialPermissionsViewController alloc] init];
    
    vocalFacialPermissionViewController.delegate = self;
    vocalFacialPermissionViewController.result = self.result;
    vocalFacialPermissionViewController.decryptedMasterKey = masterKey;
    
    //set new screen and state
    self.currentState = CurrentStateVocalFacialCreation;
    self.vocalFacialPermissionViewController = vocalFacialPermissionViewController;
    self.currentViewController = vocalFacialPermissionViewController;
}


- (void) showUnlockWithResult: (DAFWaitableResult *)result{
    
    
    SentegrityTAF_UnlockViewController *unlockViewController;
    
    unlockViewController = [[SentegrityTAF_UnlockViewController alloc] initWithNibName:@"SentegrityTAF_UnlockViewController" bundle:nil];
    
    unlockViewController.delegate = self;
    [unlockViewController setResult:result];
    
    //set new screen and state
    self.currentState = CurrentStateUnlock;
    self.unlockViewController = unlockViewController;
    self.currentViewController = unlockViewController;
    
    
}





@end
