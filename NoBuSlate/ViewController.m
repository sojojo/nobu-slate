//
//  ViewController.m
//  NoBuSlate
//
//  Created by Matthew McKenna on 5/27/12.
//  Copyright (c) 2012 Matthew McKenna. All rights reserved.
//

#import "ViewController.h"
#import "NSTimer+Blocks.h"
#import "SlateState.h"

@implementation ViewController

@synthesize countdownTimer;
@synthesize clockTimer;
@synthesize pulseColor;
@synthesize goColor;
@synthesize countdownDurationInSeconds;
@synthesize fieldArray;

@synthesize managedObjectContext;
@synthesize slateState;

long MIN = 60;

AVAudioPlayer *audioPlayerPulse;
AVAudioPlayer *audioPlayerFinished;
UITextField *activeTextField;

BOOL didAttemptStateInitialization = NO;

#pragma mark - Countdown methods

- (void)toggleCountdown
{
    if (self.countdownTimer)
    {
        [self resetCountdown];
    }
    else
    {
        [self startCountdown];
    }
}

- (void)startCountdown
{   
    int __block currentCountdown = self.countdownDurationInSeconds;
    
    void (^myBlock)() = ^() {        
        currentCountdown = currentCountdown - 1;
        
        if ([audioPlayerPulse isPlaying])
        {
            [audioPlayerPulse stop];
        }
        
        // Reached end of countdown
        if (currentCountdown <= 0)
        {
            [self setColorsWithBackgroundColor:[UIColor blackColor] 
                                     textColor:[UIColor blackColor]
                           textBackgroundColor:self.pulseColor];
            
            [audioPlayerFinished play];
        }
        else 
        {
            [self setColorsWithBackgroundColor:[UIColor blackColor] 
                                     textColor:[UIColor whiteColor]
                           textBackgroundColor:self.goColor];
            [audioPlayerPulse play]; 
        }        
    };
    
    self.countdownTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 
                                                            block:myBlock 
                                                          repeats:YES];
    
    [self setColorsWithBackgroundColor:[UIColor blackColor] 
                             textColor:[UIColor whiteColor]
                   textBackgroundColor:self.goColor];
    [audioPlayerPulse play];
    
}

- (void)resetCountdown
{
    [countdownTimer invalidate];
    countdownTimer = nil;
}

#pragma mark - Audio methods

- (void)prepareAudioFiles
{
    // Countdown up ping sounds
    NSString *soundFilePath = [[NSBundle mainBundle] pathForResource: @"countdown-pulse" ofType: @"wav"];        
    NSURL *fileUrl = [[NSURL alloc] initFileURLWithPath:soundFilePath];   
    audioPlayerPulse = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:nil];
    
    // "Go" ping sound
    soundFilePath = [[NSBundle mainBundle] pathForResource: @"countdown-finished" ofType: @"wav"];
    fileUrl = [[NSURL alloc] initFileURLWithPath:soundFilePath];   
    audioPlayerFinished = [[AVAudioPlayer alloc] initWithContentsOfURL:fileUrl error:nil];
    
    audioPlayerFinished.delegate = self;
    audioPlayerPulse.delegate = self;
    
    [audioPlayerFinished prepareToPlay];
    [audioPlayerPulse prepareToPlay];
}

- (void)audioPlayerDecodeErrorDidOccur:(AVAudioPlayer *)player error:(NSError *)error
{
    NSLog(@"%@ has error: %@", player, error);
}

- (void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    if (player == audioPlayerFinished)
    {
        [self resetCountdown];
    }
         
    [self restoreColors];    
}

#pragma mark - Color methods

- (void)setColorsWithBackgroundColor:(UIColor *)bgColor 
                           textColor:(UIColor *)textColor
                 textBackgroundColor:(UIColor *)textBgColor
{
    [self.view setBackgroundColor:bgColor];
    
    for (id field in fieldArray)
    {
        if (![field isMemberOfClass:[UIView class]])
        {
            [(UITextField *)field setTextColor:textColor];
        }
        
        [field setBackgroundColor:textBgColor];
    }
}

- (void)restoreColors
{
    [self.view setBackgroundColor:[UIColor whiteColor]];

    for (UITextField *field in fieldArray)
    {
        if (![field isMemberOfClass:[UIView class]])
        {
            [field setTextColor:[UIColor whiteColor]];
        }
        
        [field setBackgroundColor:[UIColor blackColor]];
    }
}

#pragma mark - Update views

- (void)updateDateAndTime
{
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setDateFormat:@"MMM dd, yyyy"];
    
    NSDateFormatter *timeFormat = [[NSDateFormatter alloc] init];
    [timeFormat setDateFormat:@"HH:mm"];
    
    NSDate *now = [[NSDate alloc] init];
    
    NSString *dateString = [dateFormat stringFromDate:now];
    NSString *timeString = [timeFormat stringFromDate:now];
    
    currentDateField.text = dateString;
    currentTimeField.text = timeString;
}

- (void)updateProductionName
{
    productionNameField.text = self.slateState.productionName;
    [self saveContext];
}

- (void)updateSceneNumber
{
    sceneNumberField.text = [NSString stringWithFormat:@"%d", 
                             [self.slateState.sceneNumber intValue]];
    [self saveContext];

}

- (void)updateTakeNumber
{
    takeNumberField.text = [NSString stringWithFormat:@"%d", 
                            [self.slateState.takeNumber intValue]];
    [self saveContext];
}

- (void)updateAudioFileName
{
    audioFileNameField.text = self.slateState.audioFileName;
    [self saveContext];
}

- (void)updateAudioLeftChannel
{
    audioLeftChannelField.text = self.slateState.audioLeftChannel;
    [self saveContext];
}

- (void)updateAudioRightChannel
{
    audioRightChannelField.text = self.slateState.audioRightChannel;
    [self saveContext];
}

#pragma mark - Handle core data

- (void)populateModels
{    
    NSEntityDescription *entityDesc = [NSEntityDescription entityForName:@"SlateState" inManagedObjectContext:self.managedObjectContext];
    NSFetchRequest *request = [[NSFetchRequest alloc] init];
    [request setEntity:entityDesc];
    NSError *error;

    NSArray *objects = [self.managedObjectContext executeFetchRequest:request error:&error];
    
    // TODO: Better error handling
    if ([objects count] == 0 && didAttemptStateInitialization)
    {
        NSLog(@"Error: populateModels unable to create Core Data entity.");
        return;
    }
    
    if ([objects count] == 0) 
    {
        self.slateState = [NSEntityDescription insertNewObjectForEntityForName:@"SlateState" 
                                                                    inManagedObjectContext:self.managedObjectContext];
        [self populateModels];
        
    } else 
    {
        self.slateState = [objects objectAtIndex:0];
    }
}

#pragma mark - UIControl delegate methods

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    NSLog(@"editing: %@", textField.text);
    activeTextField = textField;
}

- (void)saveContext
{
    NSError *error = nil;
    if (self.managedObjectContext != nil) {
        if ([self.managedObjectContext hasChanges] && ![self.managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. 
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        } 
    }
}

- (void)textFieldDidEndEditing:(UITextField *)textField
{
    if (textField == productionNameField)
    {
        self.slateState.productionName = productionNameField.text;
    }
    else if (textField == sceneNumberField)
    {
        self.slateState.sceneNumber = 
        [NSNumber numberWithInt:[sceneNumberField.text intValue]];
    }
    else if (textField == takeNumberField)
    {
        self.slateState.takeNumber = 
        [NSNumber numberWithInt:[takeNumberField.text intValue]];
    }
    else if (textField == audioFileNameField)
    {
        self.slateState.audioFileName = audioFileNameField.text;
    }
    else if (textField == audioLeftChannelField)
    {
        self.slateState.audioLeftChannel = audioLeftChannelField.text;
    }
    else if (textField == audioRightChannelField)
    {
        self.slateState.audioRightChannel = audioRightChannelField.text;
    }
    
    [self saveContext];
    
    activeTextField = nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField 
{
    [textField resignFirstResponder];
    return YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent: (UIEvent *)event 
{
    for (UIView* view in self.view.subviews) {
        if ([view isKindOfClass:[UITextField class]])
            [view resignFirstResponder];
    }
}

#pragma mark - Handle gestures

- (IBAction)handleUpSwipe:(id)sender
{
    UIView *touchedView = [(UISwipeGestureRecognizer *)sender view];

    if (touchedView == sceneNumberView)
    {
        int value = [self.slateState.sceneNumber intValue] + 1;
        self.slateState.sceneNumber = [NSNumber numberWithInt:value];
        [self updateSceneNumber];
    }
    else if (touchedView == takeNumberView)
    {
        int value = [self.slateState.takeNumber intValue] + 1;
        self.slateState.takeNumber = [NSNumber numberWithInt:value];        
        [self updateTakeNumber];
    }
    else if (touchedView == audioFileNameView)
    {
        // TODO: add ability to parse field with file extension
        int fileNumber = [self.slateState.audioFileName intValue] + 1;
        self.slateState.audioFileName = [NSString stringWithFormat:@"%03d", fileNumber];
        [self updateAudioFileName];
    }
}

- (IBAction)handleDownSwipe:(id)sender
{
    UIView *touchedView = [(UISwipeGestureRecognizer *)sender view];
    
    if (touchedView == sceneNumberView)
    {
        int value = [self.slateState.sceneNumber intValue] - 1;
        self.slateState.sceneNumber = [NSNumber numberWithInt:value];
        [self updateSceneNumber];
    }
    else if (touchedView == takeNumberView)
    {
        int value = [self.slateState.takeNumber intValue] - 1;
        self.slateState.takeNumber = [NSNumber numberWithInt:value];
        [self updateTakeNumber];
    }
    else if (touchedView == audioFileNameView)
    {
        int fileNumber = [self.slateState.audioFileName intValue] - 1;
        self.slateState.audioFileName = [NSString stringWithFormat:@"%03d", fileNumber];
        [self updateAudioFileName];
    }
}

- (IBAction)handleSideSwipe:(id)sender
{
    [self toggleCountdown];
}

#pragma mark - Keyboard methods

// http://developer.apple.com/library/ios/#documentation/StringsTextFonts/Conceptual/TextAndWebiPhoneOS/KeyboardManagement/KeyboardManagement.html#//apple_ref/doc/uid/TP40009542-CH5-SW7
// http://stackoverflow.com/a/4837510
// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWillShow:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    scrollContainer.contentInset = contentInsets;
    scrollContainer.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your application might not need or want this behavior.
    CGRect aRect = self.view.frame;
    aRect.size.height -= kbSize.height;
    CGPoint origin = activeTextField.frame.origin;
    origin = [activeTextField convertPoint:origin toView:activeTextField.superview];
    origin.y -= scrollContainer.contentOffset.y;
    if (!CGRectContainsPoint(aRect, origin) ) {
        CGPoint scrollPoint = CGPointMake(0.0, activeTextField.superview.frame.origin.y-(aRect.size.height)); 
        [scrollContainer setContentOffset:scrollPoint animated:YES];
    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    scrollContainer.contentInset = contentInsets;
    scrollContainer.scrollIndicatorInsets = contentInsets;
}
- (IBAction)dismissKeyboard:(id)sender
{
    [activeTextField resignFirstResponder];
}

#pragma mark - View lifecycle

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self prepareAudioFiles];
    [self updateDateAndTime];
    
    productionNameField.delegate = self;
    sceneNumberField.delegate = self;
    takeNumberField.delegate = self;
    audioFileNameField.delegate = self;
    audioLeftChannelField.delegate = self;
    audioRightChannelField.delegate = self;
    audioLeftChannelField.delegate = self;
    audioRightChannelField.delegate = self;
    self.countdownDurationInSeconds = 2;
        
    // Keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
    // This timer updates the date/time field
    self.clockTimer = [NSTimer scheduledTimerWithTimeInterval:MIN 
                                                       target:self 
                                                     selector:@selector(updateDateAndTime) 
                                                     userInfo:nil 
                                                      repeats:YES];
    
    pulseColor = [UIColor colorWithRed:0 green:0.501961 blue:0 alpha:1];
    goColor = [UIColor colorWithRed:0.501961 green:0 blue:.0 alpha:1];
    
    [self populateModels];

    [self updateAudioFileName];
    [self updateAudioLeftChannel];
    [self updateAudioRightChannel];
    [self updateProductionName];
    [self updateTakeNumber];
    [self updateSceneNumber];
    
    // TODO: Maybe there's a better way to do this...
    self.fieldArray = [NSMutableArray array];
    [self.fieldArray addObject:productionNameField];
    [self.fieldArray addObject:sceneNumberField];
    [self.fieldArray addObject:takeNumberField];
    [self.fieldArray addObject:sceneNumberView];
    [self.fieldArray addObject:takeNumberView];
    [self.fieldArray addObject:dateNumberView];
    [self.fieldArray addObject:audioFileNameView];
    [self.fieldArray addObject:channelsView];
    [self.fieldArray addObject:audioFileNameField];
    [self.fieldArray addObject:audioLeftChannelField];
    [self.fieldArray addObject:audioRightChannelField];
    [self.fieldArray addObject:currentDateField];
    [self.fieldArray addObject:currentTimeField];
    [self.fieldArray addObject:sceneLabel];
    [self.fieldArray addObject:takeLabel];
    [self.fieldArray addObject:dateTimeLabel];
    [self.fieldArray addObject:audioFileLabel];
    [self.fieldArray addObject:channelsLabel];
    [self.fieldArray addObject:lChannelLabel];
    [self.fieldArray addObject:rChannelLabel];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    if (clockTimer)
    {
        [clockTimer invalidate];
        clockTimer = nil;
    }

    if (countdownTimer)
    {
        [countdownTimer invalidate];
        countdownTimer = nil;
    }
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIKeyboardWillShowNotification 
                                                  object:nil]; 
    
    [[NSNotificationCenter defaultCenter] removeObserver:self 
                                                    name:UIKeyboardDidHideNotification 
                                                  object:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    if (interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
        interfaceOrientation == UIInterfaceOrientationLandscapeRight)
    {
        return YES;
    }
    else
    {
        return NO;
    }
    
    // Return YES for supported orientations
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
    } else {
        return YES;
    }
}

@end
