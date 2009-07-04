//
//  UKSystemSound.m
//  iPhoneTestApp
//
//  Created by Uli Kusterer on 19.06.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "UKSystemSound.h"


void UKSystemSoundAudioServicesSystemSoundCompletionProc( SystemSoundID ssID, void *clientData )
{
	if( clientData )
		[[(UKSystemSound*)clientData delegate] sound: (UKSystemSound*)clientData didFinishPlaying: YES];
	AudioServicesRemoveSystemSoundCompletion( ssID );
	[(UKSystemSound*)clientData release];
}


@implementation UKSystemSound

-(id)	initWithContentsOfURL: (NSURL*)fileURL byReference: (BOOL)ignored
{
	self = [super init];
	if( self )
	{
		OSStatus err = AudioServicesCreateSystemSoundID( (CFURLRef) fileURL, &systemSoundID );
		if( err != noErr )
		{
			[self autorelease];
			return nil;
		}
		else
			soundIDValid = YES;
	}
	return self;
}

-(void)	dealloc
{
	if( soundIDValid )
	{
		AudioServicesDisposeSystemSoundID( systemSoundID );
		soundIDValid = NO;
	}
	
	[super dealloc];
}


@synthesize delegate;

-(void)	play
{
	if( soundIDValid )
	{
		AudioServicesPlaySystemSound( systemSoundID );
		[self retain];
		AudioServicesAddSystemSoundCompletion( systemSoundID, CFRunLoopGetCurrent(), NULL,
					UKSystemSoundAudioServicesSystemSoundCompletionProc, self );
	}
}

@end
