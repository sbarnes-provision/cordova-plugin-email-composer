/*
 Licensed to the Apache Software Foundation (ASF) under one
 or more contributor license agreements.  See the NOTICE file
 distributed with this work for additional information
 regarding copyright ownership.  The ASF licenses this file
 to you under the Apache License, Version 2.0 (the
 "License"); you may not use this file except in compliance
 with the License.  You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing,
 software distributed under the License is distributed on an
 "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 KIND, either express or implied.  See the License for the
 specific language governing permissions and limitations
 under the License.
 */

#import "APPEmailComposer.h"
#import "APPEmailComposerImpl.h"

// class definition - no type?
@interface APPEmailComposer ()

// properties are instance variables that can be accessed outside the class
// access specifiers are in parens
// then the datatype
// then the property name

// Reference is needed because of the async delegate
@property (nonatomic, strong) CDVInvokedUrlCommand* command;
// Implements the core functionality
@property (nonatomic, strong) APPEmailComposerImpl* impl;

@end

@implementation APPEmailComposer

// 
@synthesize command, impl;

// organizing code under named headings
// these will create visual cues on the xcdoe source navigator and minimap
#pragma mark -
#pragma mark Lifecycle

/**
 * Initialize the core impl object which does the main stuff.
 */
- (void) pluginInitialize
{
    self.impl = [[APPEmailComposerImpl alloc] init];
}

#pragma mark -
#pragma mark Public

- (void)available:(CDVInvokedUrlCommand*)command {
  BOOL avail = NO;
  if (NSClassFromString(@"UIActivityViewController")) {
    avail = YES;
  }
  CDVPluginResult* pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsInt:avail];
  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];

/**
 * Checks if an email account is configured for use with the email composition view that opens in-app.
 */
- (void) account:(CDVInvokedUrlCommand*)cmd
{
    [self.commandDelegate runInBackground:^{
        bool res = [self.impl canSendMail];
        CDVPluginResult* result;

        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                     messageAsBool:res];

        [self.commandDelegate sendPluginResult:result
                                    callbackId:cmd.callbackId];
    }];
}

/**
 * Checks if an email client is available which responds to the scheme.
 */
- (void) client:(CDVInvokedUrlCommand*)cmd
{
    [self.commandDelegate runInBackground:^{
        NSString* scheme = [cmd argumentAtIndex:0];
        bool res         = [self.impl canOpenScheme:scheme];
        CDVPluginResult* result;

        result = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK
                                     messageAsBool:res];

        [self.commandDelegate sendPluginResult:result
                                    callbackId:cmd.callbackId];
    }];
}

/**
 * Show the email composer view with pre-filled data.
 */
- (void) open:(CDVInvokedUrlCommand*)cmd
{
    NSDictionary* props = cmd.arguments[0];

    self.command = cmd;

    [self.commandDelegate runInBackground:^{
        NSString* scheme = [props objectForKey:@"app"];

        if ([self canUseAppleMail:scheme]) {
            [self presentMailComposerFromProperties:props];
        } else {
            [self openURLFromProperties:props];
        }
    }];
}

#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate

/**
 * Delegate will be called after the mail composer did finish an action
 * to dismiss the view.
 */
- (void) mailComposeController:(MFMailComposeViewController*)controller
           didFinishWithResult:(MFMailComposeResult)result
                         error:(NSError*)error
{
    [controller dismissViewControllerAnimated:YES completion:NULL];

    [self execCallback];
}

#pragma mark -
#pragma mark Private

/**
 * Displays the email draft.
 */
- (void) presentMailComposerFromProperties:(NSDictionary*)props
{
    dispatch_async(dispatch_get_main_queue(), ^{
        MFMailComposeViewController* draft =
        [self.impl mailComposerFromProperties:props delegateTo:self];

        if (!draft) {
            [self execCallback];
            return;
        }

        [self.viewController presentViewController:draft
                                          animated:YES
                                        completion:NULL];
    });

}

/**
 * Instructs the application to open the specified URL.
 */
- (void) openURLFromProperties:(NSDictionary*)props
{
    NSURL* url = [self.impl urlFromProperties:props];

    dispatch_async(dispatch_get_main_queue(), ^{
        [[UIApplication sharedApplication] openURL:url
                                           options:@{}
                                 completionHandler:^(BOOL success) {
            [self execCallback];
        }];
    });
}

/**
 * If the specified app if the buil-in iMail framework can be used.
 */
- (BOOL) canUseAppleMail:(NSString*) scheme
{
    return [scheme hasPrefix:@"mailto"];
}

/**
 * Invokes the callback without any parameter.
 */
- (void) execCallback
{
    CDVPluginResult *result = [CDVPluginResult
                               resultWithStatus:CDVCommandStatus_OK];

    [self.commandDelegate sendPluginResult:result
                                callbackId:self.command.callbackId];
}

- (void)shareWithOptions:(CDVInvokedUrlCommand*)command {
  NSDictionary* options = [command.arguments objectAtIndex:0];
  [self shareInternal:command
          withOptions:options
    isBooleanResponse:NO
   ];
}

- (void)shareInternal:(CDVInvokedUrlCommand*)command withOptions:(NSDictionary*)options isBooleanResponse:(BOOL)boolResponse {
    if (!NSClassFromString(@"UIActivityViewController")) {
      CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"not available"];
      [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
      return;
    }

    NSString *message   = options[kShareOptionMessage];
    NSString *subject   = options[kShareOptionSubject];
    NSArray  *filenames = options[kShareOptionFiles];
    NSString *urlString = options[kShareOptionUrl];
    NSString *iPadCoordString = options[kShareOptionIPadCoordinates];
    NSArray *iPadCoordinates;

    if (iPadCoordString != nil && iPadCoordString != [NSNull null]) {
      iPadCoordinates = [iPadCoordString componentsSeparatedByString:@","];
    } else {
      iPadCoordinates = @[];
    }


    NSMutableArray *activityItems = [[NSMutableArray alloc] init];

    if (message != (id)[NSNull null] && message != nil) {
    [activityItems addObject:message];
    }

    if (filenames != (id)[NSNull null] && filenames != nil && filenames.count > 0) {
      NSMutableArray *files = [[NSMutableArray alloc] init];
      for (NSString* filename in filenames) {
        NSObject *file = [self getImage:filename];
        if (file == nil) {
          file = [self getFile:filename];
        }
        if (file != nil) {
          [files addObject:file];
        }
      }
      [activityItems addObjectsFromArray:files];
    }

    if (urlString != (id)[NSNull null] && urlString != nil) {
        [activityItems addObject:[NSURL URLWithString:[urlString SSURLEncodedString]]];
    }

    UIActivity *activity = [[UIActivity alloc] init];
    NSArray *applicationActivities = [[NSArray alloc] initWithObjects:activity, nil];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:applicationActivities];
    if (subject != (id)[NSNull null] && subject != nil) {
      [activityVC setValue:subject forKey:@"subject"];
    }

    if ([activityVC respondsToSelector:(@selector(setCompletionWithItemsHandler:))]) {
      [activityVC setCompletionWithItemsHandler:^(NSString *activityType, BOOL completed, NSArray * returnedItems, NSError * activityError) {
        if (completed == YES || activityType == nil) {
            [self cleanupStoredFiles];
        }
        if (boolResponse) {
          [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsBool:completed]
                                      callbackId:command.callbackId];
        } else {
          NSDictionary * result = @{@"completed":@(completed), @"app":activityType == nil ? @"" : activityType};
          [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result]
                                      callbackId:command.callbackId];
        }
      }];
    } else {
      // let's suppress this warning otherwise folks will start opening issues while it's not relevant
#pragma GCC diagnostic ignored "-Wdeprecated-declarations"
        [activityVC setCompletionHandler:^(NSString *activityType, BOOL completed) {
          if (completed == YES || activityType == nil) {
              [self cleanupStoredFiles];
          }
          NSDictionary * result = @{@"completed":@(completed), @"app":activityType == nil ? @"" : activityType};
          CDVPluginResult * pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsDictionary:result];
          [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        }];
#pragma GCC diagnostic warning "-Wdeprecated-declarations"
      }

    NSArray * socialSharingExcludeActivities = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"SocialSharingExcludeActivities"];
    if (socialSharingExcludeActivities!=nil && [socialSharingExcludeActivities count] > 0) {
      activityVC.excludedActivityTypes = socialSharingExcludeActivities;
    }

    dispatch_async(dispatch_get_main_queue(), ^(void){
      // iPad on iOS >= 8 needs a different approach
      if ([UIDevice currentDevice].userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        NSString* iPadCoords = [self getIPadPopupCoordinates];
        if (iPadCoords != nil && ![iPadCoords isEqual:@"-1,-1,-1,-1"]) {
          CGRect rect;
          if ([iPadCoordinates count] == 4) {

            rect = CGRectMake((int) [[iPadCoordinates objectAtIndex:0] integerValue], (int) [[iPadCoordinates objectAtIndex:1] integerValue], (int) [[iPadCoordinates objectAtIndex:2] integerValue], (int) [[iPadCoordinates objectAtIndex:3] integerValue]);
          } else {
            NSArray *comps = [iPadCoords componentsSeparatedByString:@","];
            rect = [self getPopupRectFromIPadPopupCoordinates:comps];
          }
          if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 // iOS 8.0 supported
            activityVC.popoverPresentationController.sourceView = self.webView;
            activityVC.popoverPresentationController.sourceRect = rect;
#endif
          } else {
            _popover = [[UIPopoverController alloc] initWithContentViewController:activityVC];
            _popover.delegate = self;
            [_popover presentPopoverFromRect:rect inView:self.webView permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
          }
        } else if ([activityVC respondsToSelector:@selector(popoverPresentationController)]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000 // iOS 8.0 supported
          activityVC.popoverPresentationController.sourceView = self.webView;
          // position the popup at the bottom, just like iOS < 8 did (and iPhone still does on iOS 8)
          CGRect rect;
          if ([iPadCoordinates count] == 4) {
            NSLog([[NSString alloc] initWithFormat:@"test %d", [[iPadCoordinates objectAtIndex:0] integerValue]]);
            rect = CGRectMake((int) [[iPadCoordinates objectAtIndex:0] integerValue], (int) [[iPadCoordinates objectAtIndex:1] integerValue], (int) [[iPadCoordinates objectAtIndex:2] integerValue], (int) [[iPadCoordinates objectAtIndex:3] integerValue]);
          } else {
            NSArray *comps = [NSArray arrayWithObjects:
                               [NSNumber numberWithInt:(self.viewController.view.frame.size.width/2)-200],
                               [NSNumber numberWithInt:self.viewController.view.frame.size.height],
                               [NSNumber numberWithInt:400],
                               [NSNumber numberWithInt:400],
                               nil];
            rect = [self getPopupRectFromIPadPopupCoordinates:comps];
          }
          activityVC.popoverPresentationController.sourceRect = rect;
#endif
        }
      }
      [[self getTopMostViewController] presentViewController:activityVC animated:YES completion:nil];
    });
}
@end
