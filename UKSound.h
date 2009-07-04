//
//  UKSound.h
//  MobileMoose
//
//  Created by Uli Kusterer on 14.07.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>


#define kNumberBuffers			2


@class UKSound;


@protocol UKSoundDelegate

@optional
-(void)	sound: (UKSound*)sender didFinishPlaying: (BOOL)state;

@end



@interface UKSound : NSObject
{
	AudioFileID						mAudioFile;
	AudioStreamBasicDescription		mDataFormat;
	AudioQueueRef					mQueue;
	AudioQueueBufferRef				mBuffers[kNumberBuffers];
	UInt64							mPacketIndex;
	UInt32							mNumPacketsToRead;
	AudioStreamPacketDescription *	mPacketDescs;
	BOOL							mDone;
	id<UKSoundDelegate>				delegate;
	int								maxBufferSizeBytes;
}

@property (assign) id<UKSoundDelegate> delegate;

-(id)	initWithContentsOfURL: (NSURL*)theURL;

-(void)	play;


// private:
-(void)	audioQueue: (AudioQueueRef)inAQ processBuffer: (AudioQueueBufferRef)inCompleteAQBuffer;

@end
