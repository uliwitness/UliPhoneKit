//
//  UKSystemSound.h
//  iPhoneTestApp
//
//  Created by Uli Kusterer on 19.06.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

/*
	An NSSound-like class for the iPhone OS.
*/

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>


@class UKSystemSound;


@protocol UKSystemSoundDelegate

@optional

-(void)	sound: (UKSystemSound *)sound didFinishPlaying: (BOOL)aBool;

@end


@interface UKSystemSound : NSObject
{
	BOOL						soundIDValid;
	SystemSoundID				systemSoundID;
	id<UKSystemSoundDelegate>	delegate;
}

-(id)	initWithContentsOfURL: (NSURL*)fileURL byReference: (BOOL)ignored;	// CAF, AIFF or WAV files only.

@property (nonatomic,assign) id<UKSystemSoundDelegate> delegate;

-(void)	play;

@end
