//
//  FlipViewController.m
//  FlipFramework
//
//  Created by Alex Medearis on 6/4/12.
//  Copyright (c) 2012. All rights reserved.
//

#import "FlipViewController.h"
#import "MPAnimation.h"
#import <QuartzCore/QuartzCore.h>

// Parameters for the page flip calculations
#define SKEW_MULTIPLIER 4.666667
#define DEFAULT_DURATION 0.3
#define ANGLE	90
#define MARGIN	140

// Velocity thresholds for considering finger movements to be a "swipe"
#define SWIPE_LEFT_THRESHOLD -100.0f
#define SWIPE_RIGHT_THRESHOLD 100.0f

// Constants for frame size -- this is probably not idea, but its necessary in order to layout
// pending views correctly before being displayed
#define WIDTH	1024
#define HEIGHT	768

@interface FlipViewController ()

@property(assign, nonatomic) BOOL isPanning;
@property(assign, nonatomic) BOOL isFlipFrontPage;

@property(assign, nonatomic) FlipDirection direction;

@property (strong, nonatomic) UIView *animationView;

// Layer references for during an animation
@property (strong, nonatomic) CALayer *layerFront;
@property (strong, nonatomic) CALayer *layerBack;
@property (strong, nonatomic) CALayer *layerFacing;
@property (strong, nonatomic) CALayer *layerReveal;

// Layer references for corresponding shadows
@property (strong, nonatomic) CAGradientLayer *layerFrontShadow;
@property (strong, nonatomic) CAGradientLayer *layerBackShadow;
@property (strong, nonatomic) CALayer *layerFacingShadow;
@property (strong, nonatomic) CALayer *layerRevealShadow;

@property(assign, nonatomic) CGPoint panStart;

// The next view controller to flip to
@property (strong, nonatomic) FlipViewController *nextController;

@end

@implementation FlipViewController

@synthesize row = _row;

@synthesize isAnimating = _isAnimating;
@synthesize isPanning = _isPanning;
@synthesize direction = _direction;
@synthesize isFlipFrontPage = _isFlipFrontPage;
@synthesize animationView = _animationView;


// Layers saved for reuse
@synthesize layerA = _layerA;
@synthesize layerB = _layerB;
@synthesize layerC = _layerC;
@synthesize layerD = _layerD;
@synthesize layerE = _layerE;
@synthesize layerF = _layerF;

@synthesize layerFront = _layerFront;
@synthesize layerBack = _layerBack;
@synthesize layerFacing = _layerFacing;
@synthesize layerReveal = _layerReveal;

@synthesize layerFrontShadow = _layerFrontShadow;
@synthesize layerBackShadow = _layerBackShadow;
@synthesize layerFacingShadow = _layerFacingShadow;
@synthesize layerRevealShadow = _layerRevealShadow;

@synthesize panStart = _panStart;
@synthesize nextController = _nextController;


static inline double radians (double degrees) {return degrees * M_PI/180;}
static inline double degrees (double radians) {return radians * 180/M_PI;}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ( self == [self.navigationController.viewControllers objectAtIndex:0] )
    {
        self.row = 0;
    }
    self.navigationController.navigationBarHidden = YES;

    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
	pan.delegate = self;
	[self.view addGestureRecognizer:pan];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Create the next view controller so that we can animate to it if necessary    
    //
    // Note: This is probably the portion of the code I'm least proud of.  It would be nice if there were a way to 
    // determine the next view controller based on a segue name or something else.  Instead, we simply try and instantiate the
    // next controller based on a nubmered identifier.  If it fails, assume we've reached the last page.
    
    @try {
        FlipViewController * nextController = [self.storyboard instantiateViewControllerWithIdentifier:[NSString stringWithFormat:@"%d", self.row + 1]];
        nextController.view.frame = CGRectMake(0, 0, WIDTH, HEIGHT);
        self.nextController = nextController;
        nextController.row = self.row + 1;
    }
    @catch (NSException * e) {
        NSLog(@"Last page reached.");
        self.nextController = nil;
    }
    
    
    self.view.frame = CGRectMake(0, 0, WIDTH, HEIGHT);
    [self createLayers];
}


- (void)createLayers
{	
    // Bounds isn't always updated here, so we need to use hard coded values
	CGRect bounds = CGRectMake(0, 0, WIDTH, HEIGHT);
	
    // 1-Pixel margins to anti-alias edges
	UIEdgeInsets insets = UIEdgeInsetsMake(1, 0, 1, 0);

    // Bounds for the left half of a flip
	CGRect leftRect = bounds;
    leftRect.size.width = bounds.size.width / 2;

    // Bounds for the right half of a flip
    CGRect rightRect = bounds;
    rightRect.size.width = bounds.size.width / 2;
    rightRect.origin.x = bounds.size.width / 2;
    
    // Current page views
	UIImage *layerCImage = [MPAnimation renderImageFromView:self.view withRect:leftRect transparentInsets:insets];
	UIImage *layerDImage = [MPAnimation renderImageFromView:self.view withRect:rightRect transparentInsets:insets];
    
	self.layerC = [CALayer layer];
	self.layerC.frame = (CGRect){CGPointZero, layerCImage.size};
	[self.layerC setContents:(id)[layerCImage CGImage]];
	
	self.layerD = [CALayer layer];
	self.layerD.frame = (CGRect){CGPointZero, layerDImage.size};
	[self.layerD setContents:(id)[layerDImage CGImage]];

    // Create the forward views if possible
    if(self.nextController)
    {
        UIImage *layerEImage = [MPAnimation renderImageFromView:self.nextController.view withRect:leftRect transparentInsets:insets];
        UIImage *layerFImage = [MPAnimation renderImageFromView:self.nextController.view withRect:rightRect transparentInsets:insets];
        
        self.layerE = [CALayer layer];
        self.layerE.frame = (CGRect){CGPointZero, layerCImage.size};
        [self.layerE setContents:(id)[layerEImage CGImage]];
        
        self.layerF = [CALayer layer];
        self.layerF.frame = (CGRect){CGPointZero, layerDImage.size};
        [self.layerF setContents:(id)[layerFImage CGImage]];
    }
}

#pragma mark - Gesture handlers

- (void)handlePan:(UIPanGestureRecognizer *)gestureRecognizer
{
    UIGestureRecognizerState state = [gestureRecognizer state];
	CGPoint currentPosition = [gestureRecognizer locationInView:self.view];
	
	if (state == UIGestureRecognizerStateBegan)
	{
		if ([self isAnimating]){
            return;
        }
		
		// See if touch started near one of the edges, in which case we'll pan a page turn
		if (currentPosition.x <= MARGIN)
        {
            if(self.navigationController.viewControllers.count > 1)
            {
                [self startFlipWithDirection:FlipDirectionBackward];
            }
        }
		else if (currentPosition.x >= self.view.bounds.size.width - MARGIN)
        {
            if(self.nextController)
            {
                [self startFlipWithDirection:FlipDirectionForward];
            }
        }
        else
		{
			// Do nothing for now, but it might become a swipe later
			return;
		}
		self.isAnimating = YES;
        self.isPanning = YES;
		self.panStart = currentPosition;
	}
	
	if ([self isPanning] && state == UIGestureRecognizerStateChanged)
	{
		CGFloat progress = [self progressFromPosition:currentPosition];
		BOOL wasFlipFrontPage = [self isFlipFrontPage];

		self.isFlipFrontPage = (progress < 1);
		if (wasFlipFrontPage != [self isFlipFrontPage])
		{
			// Switching between the 2 halves of the animation - between front and back sides of the page we're turning
			[self switchToStage:[self isFlipFrontPage]? 0 : 1];
		}
		if ([self isFlipFrontPage])
			[self doFlip1:progress];
		else
			[self doFlip2:progress - 1];
	}
	
	if (state == UIGestureRecognizerStateEnded || state == UIGestureRecognizerStateCancelled)
	{
		CGPoint vel = [gestureRecognizer velocityInView:gestureRecognizer.view];
		
		if ([self isPanning])
        {
            // Panning has ended, clear flags
            self.isPanning = NO;
            
			// If moving slowly, let page fall either forward or back depending on where we were
			BOOL shouldFallBack = [self isFlipFrontPage];
			
			// But, if user was swiping in an appropriate direction, go ahead and honor that
            if (vel.x < SWIPE_LEFT_THRESHOLD)
            {
                // Detected a swipe to the left
                shouldFallBack = self.direction != FlipDirectionForward;
            }
            else if (vel.x > SWIPE_RIGHT_THRESHOLD)
            {
                // Detected a swipe to the right
                shouldFallBack = self.direction == FlipDirectionForward;
            }				
			
			// finishAnimation
			if (shouldFallBack != [self isFlipFrontPage])
			{
				// 2-stage animation (we're swiping either forward or back)
				CGFloat progress = [self progressFromPosition:currentPosition];
				if (([self isFlipFrontPage] && progress > 1) || (![self isFlipFrontPage] && progress < 1))
					progress = 1;
				if (progress > 1)
					progress -= 1;
                [self animateFlip1:shouldFallBack fromProgress:progress];
			}
			else
			{
				// 1-stage animation
				CGFloat fromProgress = [self progressFromPosition:currentPosition];
				if (!shouldFallBack)
					fromProgress -= 1;
				[self animateFlip2:shouldFallBack fromProgress:fromProgress];
			}
        }
		else if (![self isAnimating])
		{
			// we weren't panning (because touch didn't start near any margin) but test for swipe
			if (vel.x < SWIPE_LEFT_THRESHOLD)
			{
				// Detected a swipe to the left
                if(self.nextController)
                {
                    [self performFlipWithDirection:FlipDirectionForward];
                }
            }
			else if (vel.x > SWIPE_RIGHT_THRESHOLD)
			{
				// Detected a swipe to the right
                if(self.navigationController.viewControllers.count > 1)
                {
                    [self performFlipWithDirection:FlipDirectionBackward];                    
                }
			}
		}
	}
}

- (void)buildLayers:(FlipDirection)aDirection
{
	BOOL forwards = aDirection == FlipDirectionForward;
    
	CGRect bounds = self.view.bounds;
    
	CGFloat scale = [[UIScreen mainScreen] scale];
    
	// We inset the panels 1 point on each side with a transparent margin to antialiase the edges
	UIEdgeInsets insets = UIEdgeInsetsMake(1, 0, 1, 0);
    
	CGRect upperRect = bounds;
	
    upperRect.size.width = bounds.size.width / 2;
	CGRect lowerRect = upperRect;
	lowerRect.origin.x += upperRect.size.width;
    
	CATransform3D transform = CATransform3DIdentity;
    
	CGFloat height = bounds.size.height;
	CGFloat width = bounds.size.width/2;
	CGFloat upperHeight = roundf(width * scale) / scale; // round heights to integer for odd height
    
	// view to hold all our sublayers
	self.animationView = [[UIView alloc] initWithFrame:self.view.bounds];
	self.animationView.backgroundColor = [UIColor clearColor];
	[self.view insertSubview:self.animationView atIndex:self.view.subviews.count];    
    
    // front Page  = the half of current view we are flipping during 1st half
	// facing Page = the other half of the current view (doesn't move, gets covered by back page during 2nd half)
	// back Page   = the half of the next view that appears on the flipping page during 2nd half
	// reveal Page = the other half of the next view (doesn't move, gets revealed by front page during 1st half)
	if(forwards)
    {
        self.layerFacing = self.layerC;
        self.layerFront = self.layerD;
        self.layerBack = self.layerE;
        self.layerReveal = self.layerF;
    }
    else
    {
        self.layerFacing = self.layerD;
        self.layerFront = self.layerC;
        self.layerBack = self.layerB;
        self.layerReveal = self.layerA;

    }
    
    self.layerReveal.anchorPoint = CGPointMake(forwards? 0 : 1, 0.5);
	self.layerReveal.position = CGPointMake(upperHeight, height/2);
	[self.animationView.layer addSublayer:self.layerReveal];
    
    self.layerFront.anchorPoint = CGPointMake(forwards? 0 : 1, 0.5);
	self.layerFront.position = CGPointMake(upperHeight, height/2);
	[self.animationView.layer addSublayer:self.layerFront];
    
	self.layerFacing.anchorPoint = CGPointMake(forwards? 1 : 0, 0.5);
	self.layerFacing.position = CGPointMake(upperHeight, height/2);
	[self.animationView.layer addSublayer:self.layerFacing];
    
	self.layerBack.anchorPoint = CGPointMake(forwards? 1 : 0, 0.5);
	self.layerBack.position = CGPointMake(upperHeight, height/2);
	
	// Create shadow layers
	self.layerFrontShadow = [CAGradientLayer layer];
	[self.layerFront addSublayer:self.layerFrontShadow];
	self.layerFrontShadow.frame = CGRectInset(self.layerFront.bounds, insets.left, insets.top);
	self.layerFrontShadow.opacity = 0.0;
	self.layerFrontShadow.colors = [NSArray arrayWithObjects:(id)[[[UIColor blackColor] colorWithAlphaComponent:0.5] CGColor], (id)[UIColor blackColor].CGColor, (id)[[UIColor clearColor] CGColor], nil];
	self.layerFrontShadow.startPoint = CGPointMake(0, 0.5);
	self.layerFrontShadow.endPoint = CGPointMake(0.5, 0.5);
	self.layerFrontShadow.locations = [NSArray arrayWithObjects:[NSNumber numberWithDouble:0], [NSNumber numberWithDouble:0.1], [NSNumber numberWithDouble:1], nil];
    
	self.layerBackShadow = [CAGradientLayer layer];
	[self.layerBack addSublayer:self.layerBackShadow];
	self.layerBackShadow.frame = CGRectInset(self.layerBack.bounds, insets.left, insets.top);
	self.layerBackShadow.opacity = 0.1;
	self.layerBackShadow.colors = [NSArray arrayWithObjects:(id)[[[UIColor blackColor] colorWithAlphaComponent:0.5] CGColor], (id)[UIColor blackColor].CGColor, (id)[[UIColor clearColor] CGColor], nil];
	self.layerBackShadow.startPoint = CGPointMake(0.5, 0.5);
	self.layerBackShadow.endPoint = CGPointMake(1, 0.5);
	self.layerBackShadow.locations = [NSArray arrayWithObjects:[NSNumber numberWithDouble:0], [NSNumber numberWithDouble:0.9], [NSNumber numberWithDouble:1], nil];
    
    self.layerRevealShadow = [CALayer layer];
    [self.layerReveal addSublayer:self.layerRevealShadow];
    self.layerRevealShadow.frame = self.layerReveal.bounds;
    self.layerRevealShadow.backgroundColor = [UIColor blackColor].CGColor;
    self.layerRevealShadow.opacity = 0.5;
    
    self.layerFacingShadow = [CALayer layer];
    [self.layerFacing addSublayer:self.layerFacingShadow];
    self.layerFacingShadow.frame = self.layerFacing.bounds;
    self.layerFacingShadow.backgroundColor = [UIColor blackColor].CGColor;
    self.layerFacingShadow.opacity = 0.0;
    
	// Perspective is best proportional to the height of the pieces being folded away, rather than a fixed value
	// the larger the piece being folded, the more perspective distance (zDistance) is needed.
	// m34 = -1/zDistance
    transform.m34 = - 1 / (width * SKEW_MULTIPLIER);
	self.animationView.layer.sublayerTransform = transform;
    
	// set shadows on the 2 pages we'll be animating
	self.layerFront.shadowOpacity = 0.5;
	self.layerFront.shadowOffset = CGSizeMake(0,3);
	[self.layerFront setShadowPath:[[UIBezierPath bezierPathWithRect:CGRectInset([self.layerFront bounds], insets.left, insets.top)] CGPath]];	
	self.layerBack.shadowOpacity = 0.5;
	self.layerBack.shadowOffset = CGSizeMake(0,3);
	[self.layerBack setShadowPath:[[UIBezierPath bezierPathWithRect:CGRectInset([self.layerBack bounds], insets.left, insets.top)] CGPath]];
}

- (CGFloat)progressFromPosition:(CGPoint)position
{
	// Determine where we are in our page turn animation
	// 0 - 1 means flipping the front-side of the page
	// 1 - 2 means flipping the back-side of the page
	BOOL isForward = (self.direction == FlipDirectionForward);
	
	CGFloat difference = position.x - self.panStart.x;
	CGFloat halfWidth = self.view.frame.size.width / 2;
	CGFloat progress = difference / halfWidth * (isForward? - 1 : 1);
	if (progress < 0)
		progress = 0;
	if (progress > 2)
		progress = 2;
	return progress;
}

- (void)performFlipWithDirection:(FlipDirection)aDirection
{
    self.isAnimating = YES;
	[self startFlipWithDirection:aDirection];
	[self animateFlip1:NO fromProgress:0];
}

- (void)startFlipWithDirection:(FlipDirection)aDirection
{
	self.direction = aDirection;
    self.isFlipFrontPage = YES;
    
	[self buildLayers:aDirection];
    
	// set the back page in the vertical position (midpoint of animation)
	[self doFlip2:0];
}


- (void)animateFlip1:(BOOL)shouldFallBack fromProgress:(CGFloat)fromProgress
{
	// 2-stage animation
	CALayer *layer = shouldFallBack? self.layerBack : self.layerFront;
	CALayer *flippingShadow = shouldFallBack? self.layerBackShadow : self.layerFrontShadow;
	CALayer *coveredShadow = shouldFallBack? self.layerFacingShadow : self.layerRevealShadow;
	
	if (shouldFallBack)
		fromProgress = 1 - fromProgress;
	CGFloat toProgress = 1;
    
	// Figure out how many frames we want
	CGFloat duration = DEFAULT_DURATION * (toProgress - fromProgress);
	NSUInteger frameCount = ceilf(duration * 60); // we want 60 FPS
	
	// Create a transaction
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:duration] forKey:kCATransactionAnimationDuration];
	[CATransaction setValue:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseIn] forKey:kCATransactionAnimationTimingFunction];
	[CATransaction setCompletionBlock:^{
		// 2nd half of animation, once 1st half completes
        self.isFlipFrontPage = shouldFallBack;\
		[self switchToStage:shouldFallBack? 0 : 1];
		
		[self animateFlip2:shouldFallBack fromProgress:shouldFallBack? 1 : 0];
	}];
	
	// Create the animation
	BOOL forwards = [self direction] == FlipDirectionForward;
	BOOL vertical = false;
	BOOL inward = NO;
	NSString *rotationKey = vertical? @"transform.rotation.x" : @"transform.rotation.y";
	double factor = (shouldFallBack? -1 : 1) * (forwards? -1 : 1) * (vertical? -1 : 1) * M_PI / 180;
    
	// Flip front page from flat up to vertical
	CABasicAnimation* animation = [CABasicAnimation animationWithKeyPath:rotationKey];
	[animation setFromValue:[NSNumber numberWithDouble:90 * factor * fromProgress]];
	[animation setToValue:[NSNumber numberWithDouble:90*factor]];
	[layer addAnimation:animation forKey:nil];
	[layer setTransform:CATransform3DMakeRotation(90*factor, vertical? 1 : 0, vertical? 0 : 1, 0)];
    
	// Shadows
	
	// darken front page just slightly as we flip (just to give it a crease where it touches facing page)
	animation = [CABasicAnimation animationWithKeyPath:@"opacity"];
	[animation setFromValue:[NSNumber numberWithDouble:0.1 * fromProgress]];
	[animation setToValue:[NSNumber numberWithDouble:0.1]];
	[flippingShadow addAnimation:animation forKey:nil];
	[flippingShadow setOpacity:0.1];
	
	if (!inward)
	{
		// lighten the page that is revealed by front page flipping up (along a cosine curve)
		// TODO: consider FROM value
		NSMutableArray* arrayOpacity = [NSMutableArray arrayWithCapacity:frameCount + 1];
		CGFloat progress;
		CGFloat cosOpacity;
		for (int frame = 0; frame <= frameCount; frame++)
		{
			progress = fromProgress + (toProgress - fromProgress) * ((float)frame) / frameCount;
			//progress = (((float)frame) / frameCount);
			cosOpacity = cos(radians(90 * progress)) * (1./3);
			if (frame == frameCount)
				cosOpacity = 0;
			[arrayOpacity addObject:[NSNumber numberWithFloat:cosOpacity]];
		}
		
		CAKeyframeAnimation *keyAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		[keyAnimation setValues:[NSArray arrayWithArray:arrayOpacity]];
		[coveredShadow addAnimation:keyAnimation forKey:nil];
		[coveredShadow setOpacity:[[arrayOpacity lastObject] floatValue]];
	}
	
	// shadow opacity should fade up from 0 to 0.5 at 12.5% progress then remain there through 100%
	NSMutableArray* arrayOpacity = [NSMutableArray arrayWithCapacity:frameCount + 1];
	CGFloat progress;
	CGFloat shadowProgress;
	for (int frame = 0; frame <= frameCount; frame++)
	{
		progress = fromProgress + (toProgress - fromProgress) * ((float)frame) / frameCount;
		shadowProgress = progress * 8;
		if (shadowProgress > 1)
			shadowProgress = 1;
		
		[arrayOpacity addObject:[NSNumber numberWithFloat:0.5 * shadowProgress]];
	}
	
	CAKeyframeAnimation *keyAnimation = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
	[keyAnimation setCalculationMode:kCAAnimationLinear];
	[keyAnimation setValues:arrayOpacity];
	[layer addAnimation:keyAnimation forKey:nil];
	[layer setShadowOpacity:[[arrayOpacity lastObject] floatValue]];
	
	// Commit the transaction for 1st half
	[CATransaction commit];
}

- (void)animateFlip2:(BOOL)shouldFallBack fromProgress:(CGFloat)fromProgress
{
	// 1-stage animation
	CALayer *layer = shouldFallBack? self.layerFront : self.layerBack;
	CALayer *flippingShadow = shouldFallBack? self.layerFrontShadow : self.layerBackShadow;
	CALayer *coveredShadow = shouldFallBack? self.layerRevealShadow : self.layerFacingShadow;
	
	// Figure out how many frames we want
	CGFloat duration = DEFAULT_DURATION;
	NSUInteger frameCount = ceilf(duration * 60); // we want 60 FPS
	
	// Build an array of keyframes (each a single transform)
	if (shouldFallBack)
		fromProgress = 1 - fromProgress;
	CGFloat toProgress = 1;
	
	// Create a transaction
	[CATransaction begin];
	[CATransaction setValue:[NSNumber numberWithFloat:duration] forKey:kCATransactionAnimationDuration];
	[CATransaction setValue:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut] forKey:kCATransactionAnimationTimingFunction];
	[CATransaction setCompletionBlock:^{
		// once 2nd half completes
		[self endFlip:!shouldFallBack];
		
		// Clear flags
        self.isAnimating = NO;
	}];
	
	// Create the animation
	BOOL forwards = [self direction] == FlipDirectionForward;
	BOOL vertical = false;
	BOOL inward = NO;
	NSString *rotationKey = vertical? @"transform.rotation.x" : @"transform.rotation.y";
	double factor = (shouldFallBack? -1 : 1) * (forwards? -1 : 1) * (vertical? -1 : 1) * M_PI / 180;
	
	// Flip back page from vertical down to flat
	CABasicAnimation* animation2 = [CABasicAnimation animationWithKeyPath:rotationKey];
	[animation2 setFromValue:[NSNumber numberWithDouble:-90*factor*(1-fromProgress)]];
	[animation2 setToValue:[NSNumber numberWithDouble:0]];
	[animation2 setFillMode:kCAFillModeForwards];
	[animation2 setRemovedOnCompletion:NO];
	[layer addAnimation:animation2 forKey:nil];
	[layer setTransform:CATransform3DIdentity];
	
	// Shadows
	
	// Lighten back page just slightly as we flip (just to give it a crease where it touches reveal page)
	animation2 = [CABasicAnimation animationWithKeyPath:@"opacity"];
	[animation2 setFromValue:[NSNumber numberWithDouble:0.1 * (1-fromProgress)]];
	[animation2 setToValue:[NSNumber numberWithDouble:0]];
	[animation2 setFillMode:kCAFillModeForwards];
	[animation2 setRemovedOnCompletion:NO];
	[flippingShadow addAnimation:animation2 forKey:nil];
	[flippingShadow setOpacity:0];
	
	if (!inward)
	{
		// Darken facing page as it gets covered by back page flipping down (along a sine curve)
		NSMutableArray* arrayOpacity = [NSMutableArray arrayWithCapacity:frameCount + 1];
		CGFloat progress;
		CGFloat sinOpacity;
		for (int frame = 0; frame <= frameCount; frame++)
		{
			progress = fromProgress + (toProgress - fromProgress) * ((float)frame) / frameCount;
			sinOpacity = (sin(radians(90 * progress))* (1./3));
			if (frame == 0)
				sinOpacity = 0;
			[arrayOpacity addObject:[NSNumber numberWithFloat:sinOpacity]];
		}
		
		CAKeyframeAnimation *keyAnimation = [CAKeyframeAnimation animationWithKeyPath:@"opacity"];
		[keyAnimation setValues:[NSArray arrayWithArray:arrayOpacity]];
		[coveredShadow addAnimation:keyAnimation forKey:nil];
		[coveredShadow setOpacity:[[arrayOpacity lastObject] floatValue]];
	}
	
	// shadow opacity on flipping page should be 0.5 through 87.5% progress then fade to 0 at 100%
	NSMutableArray* arrayOpacity = [NSMutableArray arrayWithCapacity:frameCount + 1];
	CGFloat progress;
	CGFloat shadowProgress;
	for (int frame = 0; frame <= frameCount; frame++)
	{
		progress = fromProgress + (toProgress - fromProgress) * ((float)frame) / frameCount;
		shadowProgress = (1 - progress) * 8;
		if (shadowProgress > 1)
			shadowProgress = 1;
		
		[arrayOpacity addObject:[NSNumber numberWithFloat:0.5 * shadowProgress]];
	}
	
	CAKeyframeAnimation *keyAnimation = [CAKeyframeAnimation animationWithKeyPath:@"shadowOpacity"];
	[keyAnimation setCalculationMode:kCAAnimationLinear];
	[keyAnimation setValues:arrayOpacity];
	[layer addAnimation:keyAnimation forKey:nil];
	[layer setShadowOpacity:[[arrayOpacity lastObject] floatValue]];
	
	// Commit the transaction
	[CATransaction commit];
}


- (void)doFlip1:(CGFloat)progress
{
    [CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
	if (progress < 0)
		progress = 0;
	else if (progress > 1)
		progress = 1;
    
	[self.layerFront setTransform:[self flipTransform1:progress]];
    [self.layerFrontShadow setOpacity:0.1 * progress];
	CGFloat cosOpacity = cos(radians(90 * progress)) * (1./3);
	[self.layerRevealShadow setOpacity:cosOpacity];
	
	// shadow opacity should fade up from 0 to 0.5 at 12.5% progress then remain there through 100%
	CGFloat shadowProgress = progress * 8;
	if (shadowProgress > 1)
		shadowProgress = 1;
	[self.layerFront setShadowOpacity:0.5 * shadowProgress];
    
	[CATransaction commit];
}

- (void)doFlip2:(CGFloat)progress
{
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
    
	if (progress < 0)
		progress = 0;
	else if (progress > 1)
		progress = 1;
	
	[self.layerBack setTransform:[self flipTransform2:progress]];
	[self.layerBackShadow setOpacity:0.1 * (1- progress)];
	CGFloat sinOpacity = sin(radians(90 * progress)) * (1./3);
	[self.layerFacingShadow setOpacity:sinOpacity];
	
	// shadow opacity on flipping page should be 0.5 through 87.5% progress then fade to 0 at 100%
	CGFloat shadowProgress = (1 - progress) * 8;
	if (shadowProgress > 1)
		shadowProgress = 1;
	[self.layerBack setShadowOpacity:0.5 * shadowProgress];
    
	[CATransaction commit];
}

- (CATransform3D)flipTransform1:(CGFloat)progress
{
	CATransform3D tHalf1 = CATransform3DIdentity;
    
	// rotate away from viewer
	BOOL isForward = (self.direction == FlipDirectionForward);
	BOOL isVertical = false;
	tHalf1 = CATransform3DRotate(tHalf1, radians(ANGLE * progress * (isForward? -1 : 1)), isVertical? -1 : 0, isVertical? 0 : 1, 0);
	
	return tHalf1;
}

- (CATransform3D)flipTransform2:(CGFloat)progress
{
	CATransform3D tHalf2 = CATransform3DIdentity;
    
	// rotate away from viewer
	BOOL isForward = (self.direction == FlipDirectionForward);
	BOOL isVertical = false;
	tHalf2 = CATransform3DRotate(tHalf2, radians(ANGLE * (1 - progress)) * (isForward? 1 : -1), isVertical? -1 : 0, isVertical? 0 : 1, 0);
    
	return tHalf2;
}

// switching between the 2 halves of the animation - between front and back sides of the page we're turning
- (void)switchToStage:(int)stageIndex
{
	// 0 = stage 1, 1 = stage 2
	[CATransaction begin];
	[CATransaction setValue:(id)kCFBooleanTrue forKey:kCATransactionDisableActions];
	
	if (stageIndex == 0)
	{
		[self doFlip2:0];
		[self.animationView.layer insertSublayer:self.layerFacing above:self.layerReveal];
		[self.animationView.layer insertSublayer:self.layerFront below:self.layerFacing];
		[self.layerReveal addSublayer:self.layerRevealShadow];
		[self.layerBack removeFromSuperlayer];
		[self.layerFacingShadow removeFromSuperlayer];
	}
	else
	{
		[self doFlip1:1];
		[self.animationView.layer insertSublayer:self.layerReveal above:self.layerFacing];
		[self.animationView.layer insertSublayer:self.layerBack below:self.layerReveal];
		[self.layerFacing addSublayer:self.layerFacingShadow];
		[self.layerFront removeFromSuperlayer];
		[self.layerRevealShadow removeFromSuperlayer];
	}
	
	[CATransaction commit];
}

- (void)endFlip:(BOOL)completed
{
	// cleanup	
    
	[self.animationView removeFromSuperview];
    
    self.layerA.sublayers = nil;
    self.layerB.sublayers = nil;
    self.layerC.sublayers = nil;
    self.layerD.sublayers = nil;
    self.layerE.sublayers = nil;
    self.layerF.sublayers = nil;
    
    [self.layerA removeAllAnimations];
    [self.layerB removeAllAnimations];
    [self.layerC removeAllAnimations];
    [self.layerD removeAllAnimations];
    [self.layerE removeAllAnimations];
    [self.layerF removeAllAnimations];
    
	self.animationView = nil;
	self.layerFront = nil;
	self.layerBack = nil;
	self.layerFacing = nil;
	self.layerReveal = nil;
	self.layerFrontShadow = nil;
	self.layerBackShadow = nil;
	self.layerFacingShadow = nil;
	self.layerRevealShadow = nil;
	
	if (completed)
	{
        BOOL isForward = (self.direction == FlipDirectionForward);

        if(isForward)
        {
                       
            self.nextController.layerA = self.layerC;
            self.nextController.layerB = self.layerD;
            if(self.nextController){
                [self.navigationController pushViewController:self.nextController animated:NO];                            
            }
        }
        else 
        {
            [self.navigationController popViewControllerAnimated:NO];
        }
	}
}




- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Only supports landscape for now.
    return (interfaceOrientation == UIInterfaceOrientationLandscapeRight || interfaceOrientation == UIInterfaceOrientationLandscapeLeft);
}

@end
