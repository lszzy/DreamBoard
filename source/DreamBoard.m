#import "DreamBoard.h"

@implementation DreamBoard
static DreamBoard *sharedInstance;
@synthesize appsArray, hiddenSet, isEditing, window, cachePath, scanPath, backgroundPath, shadowPath, shadowImagePath, dbtheme;

- (id)init
{
    self = [super init];
    if (self) {
        //initialization
        appsArray = [[NSMutableArray alloc] init];
        hiddenSet = [[NSMutableSet alloc] init];
        
        //get hidden apps
        {
            NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/LibHide/hidden.plist"];
            NSArray *hideMe = [NSArray arrayWithObjects: @"com.apple.AdSheetPhone", @"com.apple.DataActivation", @"com.apple.DemoApp", @"com.apple.iosdiagnostics", @"com.apple.iphoneos.iPodOut", @"com.apple.TrustMe", @"com.apple.WebSheet", nil];
            [hiddenSet addObjectsFromArray:hideMe];
            if(dict && [dict objectForKey:@"Hidden"]){
                [hiddenSet addObjectsFromArray:[dict objectForKey:@"Hidden"]];
                [dict release];
            }
        }
        
        //load prefs
        {
            prefsPath = [[NSMutableDictionary alloc] init];

            [prefsPath setObject:@"/var/mobile/Library/Preferences/com.wynd.dreamboard.plist" forKey:@"Path"];
            
            NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:[prefsPath objectForKey:@"Path"]];
            if(dict){
                prefsDict = [dict mutableCopy];
                [dict release];
            }
            
            if( !prefsDict )
                prefsDict = [NSMutableDictionary dictionary];
            
            [prefsPath setObject:prefsDict forKey:@"Prefs"];
        }
    }
    
    return self;
}

+(DreamBoard*)sharedInstance{
    //create a new shared instance, if not already created
    if(!sharedInstance)sharedInstance = [[DreamBoard alloc] init];
    return sharedInstance;
}


- (void)dealloc
{
    //probably won't ever happen, but just to be safe
    [cachePath release];
    [scanPath release];
    [backgroundPath release];
    [shadowPath release];
    [shadowImagePath release];
    [appsArray release];
    [window release];
    [hiddenSet release];
    [prefsDict release];
    [super dealloc];
}

-(void)show{
    window.userInteractionEnabled = NO;
    //add switcher, make sure the window is visible
    switcher = [[ExposeSwitcher alloc] init];
    switcher.cachePath = cachePath;
    switcher.scanPath  = scanPath;
    switcher.current   = [self currentTheme];
    switcher.backgroundPath = backgroundPath;
    switcher.shadowPath = shadowPath;
    switcher.delegate = self;
    [ExposeSwitcher setShadowImagePath:shadowImagePath];
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y = frame.size.height-20;
    frame.size.height = 20;
    loading = [[DBLoadingView alloc] initWithFrame:frame];
    loading.label.text = @"Preparing theme switcher";
    [window addSubview:loading];
    [loading release];
    [self performSelector:@selector(addSwitcher) withObject:nil afterDelay:0];
}

-(void)aboutToZoomIn:(ExposeSwitcherObject *)theme{
    CGRect frame = [[UIScreen mainScreen] bounds];
    frame.origin.y = frame.size.height-20;
    frame.size.height = 20;
    loading = [[DBLoadingView alloc] initWithFrame:frame];
    loading.label.text = @"Preparing theme";
    [window addSubview:loading];
    [loading release];
}

-(void)addSwitcher{
    [switcher updateCache];
    //[loading removeFromSuperview];
    [window addSubview:switcher.view];
    [loading hide];
}

-(void)didSelectObject:(NSString*)object view:(ExposeSwitcher *)view{
    window.userInteractionEnabled = NO;
    [self showAllExcept:view.view];
    [self loadTheme:object];
    [loading hide];
}
-(void)didFinishSelection:(ExposeSwitcher *)view{
    [view release];
    window.userInteractionEnabled = YES;
}

-(void)didFadeOut:(ExposeSwitcher *)view{
    [self hideAllExcept:view.view];
    if(![[[prefsPath objectForKey:@"Prefs"] objectForKey:@"Launched"] boolValue]){
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome" message:@"Welcome to Dreamboard! Tap on any theme to switch to it. Tap and hold on any theme to see more options." delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
        [alert show];
        [alert release];
        [[prefsPath objectForKey:@"Prefs"] setObject:[NSNumber numberWithBool:YES] forKey:@"Launched"];
        [[prefsPath objectForKey:@"Prefs"] writeToFile:[prefsPath objectForKey:@"Path"] atomically:YES];
    }
}

-(void)hideAllExcept:(UIView *)view{
    if(hidden)return;
    for(UIView *_view in window.subviews)
        if(_view!=view && ![view.description hasPrefix:@"<SBAppContextHostView"] && ![view.description hasPrefix:@"<SBHostWrapperView"])
            _view.hidden = YES;
    hidden^=1;
}

-(void)showAllExcept:(UIView *)_view{
    if(!hidden)return;
    for(UIView *view in window.subviews)
        if(view!=_view && ![view.description hasPrefix:@"<SBAppContextHostView"] && ![view.description hasPrefix:@"<SBHostWrapperView"])
            view.hidden = NO;
    hidden^=1;
}

-(void)didHold:(ExposeSwitcherObject*)object{
    ExpObj = object;
    NSDictionary *dict = [[NSDictionary alloc] initWithContentsOfFile:[NSString stringWithFormat:@"%@/DreamBoard/%@/Info.plist", MAINPATH, object.name]];
    if(!dict)return;
    UIAlertView *alert;
    if([dict objectForKey:@"NoneEditable"]!=nil&&[[dict objectForKey:@"NoneEditable"] boolValue])
        alert = [[UIAlertView alloc] initWithTitle:object.name message:[dict objectForKey:@"Description"] delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles: nil];
    else
        alert = [[UIAlertView alloc] initWithTitle:object.name message:[dict objectForKey:@"Description"] delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Edit", @"Reset", nil];
    [alert show];
    [alert release];
    [dict release];
}

-(void)didFinishZoomingOut:(ExposeSwitcher *)view{
    window.userInteractionEnabled = YES;
}

-(NSString*)currentTheme{
    return currentTheme!=nil?currentTheme:@"Default";
}

-(void)hideSwitcher{
    if(dbtheme){
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.25];
        dbtheme->mainView.frame = CGRectMake(0, 0, dbtheme->mainView.frame.size.width, dbtheme->mainView.frame.size.height);
        [UIView commitAnimations];
    }
}
-(void)showSwitcher{
    if(dbtheme){
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.25];
        dbtheme->mainView.frame = CGRectMake(0, -93, dbtheme->mainView.frame.size.width, dbtheme->mainView.frame.size.height);
        [UIView commitAnimations];
    }
}
-(void)toggleSwitcher{
    if(dbtheme){
    if(dbtheme->mainView.frame.origin.y == -93)
        [self hideSwitcher];
    else
        [self showSwitcher];
    }
}
-(void)startEditing{
    isEditing = YES;
    dbtheme.isEditing = YES;
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Editing Mode" message:@"Welcome to editing mode. Tap on any app icon placeholder to change the icon. Press the home button when you are done!" delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
    [alert show];
    [alert release];
    if(dbtheme)
    for(DBAppIcon *app in dbtheme->allAppIcons)
        if(app.loaded){
            [app unloadIcon];
            [app loadIcon:YES shouldCache:NO];
        }
}
-(void)stopEditing{
    isEditing = NO;
    dbtheme.isEditing = NO;
    if(dbtheme)
    for(DBAppIcon *app in dbtheme->allAppIcons)
        if(app.loaded){
            [app unloadIcon];
            [app loadIcon:NO shouldCache:NO];
        }
    [dbtheme savePlist];
}
-(void)updateBadgeForApp:(NSString*)leafIdentifier{
    if(dbtheme)
    for(DBAppIcon *app in dbtheme->allAppIcons)
        if(app.application && [[app.application leafIdentifier] isEqualToString:leafIdentifier] && app.loaded){
            [app unloadIcon];
            [app loadIcon:dbtheme.isEditing shouldCache:NO];
        }
}
-(void)loadTheme:(NSString*) theme{
    if([theme isEqualToString:self.currentTheme])return;
    //unloading?
    if([theme isEqualToString:@"Default"]){
        //if there is already a theme, unload it
        if(currentTheme)
            [self unloadTheme];
        [[prefsPath objectForKey:@"Prefs"] setObject:theme forKey:@"Current Theme"];
        [[prefsPath objectForKey:@"Prefs"] writeToFile:[prefsPath objectForKey:@"Path"] atomically:YES];
        return;
    }
    if(dbtheme)[self unloadTheme];
    [currentTheme release];
    currentTheme = [theme retain];
    dbtheme = [[DBTheme alloc] initWithName:theme window:window];
    if(isEditing)
    dbtheme.isEditing = YES;
    [dbtheme loadTheme];
    [[prefsPath objectForKey:@"Prefs"] setObject:theme forKey:@"Current Theme"];
    [[prefsPath objectForKey:@"Prefs"] writeToFile:[prefsPath objectForKey:@"Path"] atomically:YES];
    //keep track of current theme
}
-(void)unloadTheme{
    window.userInteractionEnabled = NO;
    if(dbtheme){
        [dbtheme release];
        dbtheme = nil;
    }
    if(currentTheme){
        [currentTheme release];
        currentTheme = nil;
    }
    window.userInteractionEnabled = YES;
}

+(void)throwRuntimeException:(NSString*)msg shouldExit:(BOOL)exit{
    if(exit)
        [[[[UIAlertView alloc] initWithTitle:@"Runtime Error" message:msg delegate:[DreamBoard sharedInstance] cancelButtonTitle:@"Continue" otherButtonTitles:@"Exit",nil] autorelease] show];
    else
        [[[[UIAlertView alloc] initWithTitle:@"Runtime Error" message:msg delegate:[DreamBoard sharedInstance] cancelButtonTitle:@"Continue" otherButtonTitles:nil] autorelease] show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if([alertView.title isEqualToString:@"Runtime Error"]){
        if (buttonIndex != [alertView cancelButtonIndex])
            [self unloadTheme];
    }else{
        if (buttonIndex == [alertView cancelButtonIndex])return;
        if(buttonIndex == 1){
            [[ExposeSwitcher sharedInstance] switchTo:ExpObj];
            if(dbtheme!=nil && [ExpObj.name isEqualToString:currentTheme])
                [self startEditing];
            else{
                isEditing = YES;
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Editing Mode" message:@"Welcome to editing mode. Tap on any app icon placeholder to change the icon. Press the home button when you are done!" delegate:nil cancelButtonTitle:@"Dismiss" otherButtonTitles:nil];
                [alert show];
                [alert release];
            }
        }else if(buttonIndex == 2){
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/DreamBoard/%@/Current.plist", MAINPATH, alertView.title] error:nil];
            [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/DreamBoard/_library/Cache/Icons/%@", MAINPATH, alertView.title] error:nil];
        }
    }
}

+(NSString *)replaceRootDir:(NSString *)str{
    return [str stringByReplacingOccurrencesOfString:@"$ROOT" withString:[NSString stringWithFormat:@"/DreamBoard/%@", [[DreamBoard sharedInstance] currentTheme]]];
}

-(void)preLoadTheme{
    if(![[[prefsPath objectForKey:@"Prefs"] objectForKey:@"Current Theme"] isEqualToString:@"Default"])
        [self loadTheme:[[prefsPath objectForKey:@"Prefs"] objectForKey:@"Current Theme"]];
}

-(void)save:(NSString *)theme{
    [[prefsPath objectForKey:@"Prefs"] setObject:theme forKey:@"Current Theme"];
    [[prefsPath objectForKey:@"Prefs"] writeToFile:[prefsPath objectForKey:@"Path"] atomically:YES];
}

@end
