//
//  UKSound.m
//  MobileMoose
//
//  Created by Uli Kusterer on 14.07.08.
//  Copyright 2008 The Void Software. All rights reserved.
//

#import "UKSound.h"


static void UKSoundAQBufferCallback(void *					inUserData,
									AudioQueueRef			inAQ,
									AudioQueueBufferRef		inCompleteAQBuffer)
{
	UKSound*	myself = (UKSound*)inUserData;
	
	[myself audioQueue: inAQ processBuffer: inCompleteAQBuffer];
}


static void	UKSoundAQPropertyListenerCallback( void *                  inUserData,
												AudioQueueRef           inAQ,
												AudioQueuePropertyID    inID)
{
	[(UKSound*)inUserData performSelectorOnMainThread: @selector(notifyDelegatePlaybackStateChanged:) withObject: nil waitUntilDone: NO];
}


@implementation UKSound

@synthesize delegate;

-(id)	initWithContentsOfURL: (NSURL*)theURL
{
	self = [super init];
	if( self )
	{
		maxBufferSizeBytes = 0x10000;
		OSStatus	err = AudioFileOpenURL(	(CFURLRef)theURL, kAudioFileReadPermission, 0, &mAudioFile );
		if( err != noErr )
			NSLog(@"Couldn't open AudioFile.");
		UInt32 size = sizeof(mDataFormat);
		err = AudioFileGetProperty( mAudioFile, kAudioFilePropertyDataFormat, &size, &mDataFormat );
		if( err != noErr )
			NSLog(@"Couldn't determine audio file format.");
		err = AudioQueueNewOutput( &mDataFormat, UKSoundAQBufferCallback, self, NULL, NULL, 0, &mQueue );
		if( err != noErr )
			NSLog(@"Couldn't create new output for queue.");

		// We have a couple of things to take care of now
		// (1) Setting up the conditions around VBR or a CBR format - affects how we will read from the file
		// if format is VBR we need to use a packet table.
		if( mDataFormat.mBytesPerPacket == 0 || mDataFormat.mFramesPerPacket == 0 )
		{
			// first check to see what the max size of a packet is - if it is bigger
			// than our allocation default size, that needs to become larger
			UInt32 maxPacketSize;
			size = sizeof(maxPacketSize);
			err = AudioFileGetProperty( mAudioFile, kAudioFilePropertyPacketSizeUpperBound, &size, &maxPacketSize);
			if( err != noErr )
				NSLog(@"Couldn't get max packet size of audio file.");
			if( maxPacketSize > maxBufferSizeBytes ) 
				maxBufferSizeBytes = maxPacketSize;
			
			// we also need packet descpriptions for the file reading
			mNumPacketsToRead = maxBufferSizeBytes / maxPacketSize;
			mPacketDescs = malloc( sizeof(AudioStreamPacketDescription) * mNumPacketsToRead );
		}
		else
		{
			mNumPacketsToRead = maxBufferSizeBytes / mDataFormat.mBytesPerPacket;
			mPacketDescs = NULL;
		}

		// (2) If the file has a cookie, we should get it and set it on the AQ
		size = sizeof(UInt32);
		err = AudioFileGetPropertyInfo( mAudioFile, kAudioFilePropertyMagicCookieData, &size, NULL );
		if( !err && size )
		{
			char* cookie = malloc( size );
			err = AudioFileGetProperty( mAudioFile, kAudioFilePropertyMagicCookieData, &size, cookie );
			if( err != noErr )
				NSLog(@"Couldn't get magic cookie of audio file.");
			err = AudioQueueSetProperty( mQueue, kAudioQueueProperty_MagicCookie, cookie, size );
			if( err != noErr )
				NSLog(@"Couldn't transfer magic cookie of audio file to qudio queue.");
			free( cookie );
		}
		
		err = AudioQueueAddPropertyListener( mQueue, kAudioQueueProperty_IsRunning,
                                    UKSoundAQPropertyListenerCallback,
                                    self );
		if( err != noErr )
			NSLog(@"Couldn't register for playback state changes.");
		
			// prime the queue with some data before starting
		mDone = false;
		mPacketIndex = 0;
		for( int i = 0; i < kNumberBuffers; ++i )
		{
			err = AudioQueueAllocateBuffer( mQueue, maxBufferSizeBytes, &mBuffers[i] );
			if( err != noErr )
				NSLog(@"Couldn't allocate buffer %d.", i);

			UKSoundAQBufferCallback( self, mQueue, mBuffers[i] );
			
			if( mDone ) break;
		}
	}
	
	return self;
}


-(void)	dealloc
{
	OSStatus err = AudioQueueDispose( mQueue, true );
	err = AudioFileClose( mAudioFile );
	if( mPacketDescs )
		free( mPacketDescs );
	
	[super dealloc];
}


-(void)	play
{
	OSStatus err = AudioQueueStart( mQueue, NULL );
	if( err != noErr )
		NSLog(@"Couldn't start audio queue.");
	else
		[self retain];
}


-(BOOL)	isPlaying
{
	UInt32		state = NO,
				size = sizeof(UInt32);
	OSStatus	err = AudioQueueGetProperty( mQueue, kAudioQueueProperty_IsRunning, &state, &size );
	if( err != noErr )
		NSLog(@"Couldn't get play state of queue.");
	
	return state;
}


-(void)	notifyDelegatePlaybackStateChanged: (id)sender;
{
	if( ![self isPlaying] )
	{
		[delegate sound: self didFinishPlaying: YES];
		
		AudioQueueStop( mQueue, false );
		[self release];
	}
}


-(void)	audioQueue: (AudioQueueRef)inAQ processBuffer: (AudioQueueBufferRef)inCompleteAQBuffer
{
	if( mDone )
		return;
		
	UInt32 numBytes;
	UInt32 nPackets = mNumPacketsToRead;

	// Read nPackets worth of data into buffer
	OSStatus err = AudioFileReadPackets( mAudioFile, false, &numBytes, mPacketDescs, mPacketIndex, &nPackets, 
										inCompleteAQBuffer->mAudioData);
	if( err != noErr )
		NSLog(@"Couldn't read into buffer.");
	
	if (nPackets > 0)
	{
		inCompleteAQBuffer->mAudioDataByteSize = numBytes;		

		// Queues the buffer for audio input/output.
		err = AudioQueueEnqueueBuffer( inAQ, inCompleteAQBuffer, (mPacketDescs ? nPackets : 0), mPacketDescs );
		if( err != noErr )
			NSLog(@"Couldn't enqueue buffer.");
		
		mPacketIndex += nPackets;
	}
	else
	{
		UInt32		state = NO,
					size = sizeof(UInt32);
		OSStatus	err = AudioQueueGetProperty( mQueue, kAudioQueueProperty_IsRunning, &state, &size );
		
		// I should be calling the following, but it always makes the app hang.
		if( state )
		{
			err = AudioQueueStop( mQueue, false );
			if( err != noErr )
				NSLog(@"Couldn't stop queue.");
				// reading nPackets == 0 is our EOF condition
		}
		mDone = true;
	}
}

@end
