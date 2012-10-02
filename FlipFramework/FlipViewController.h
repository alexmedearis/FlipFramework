//
//  FlipViewController.h
//  FlipTest
//
//  Created by Alex Medearis on 6/4/12.
//  Copyright (c) 2012. All rights reserved.
//

#import <UIKit/UIKit.h>

typedef enum {
	FlipDirectionForward,
	FlipDirectionBackward
} FlipDirection;

@interface FlipViewController : UIViewController<UIGestureRecognizerDelegate>
{

}
@property(assign, nonatomic) BOOL isAnimating;
@property (assign, nonatomic) int row;

// Layers should be created in advance for snappier UI
// The layers are:
// A - Previous Left
// B - Previous Right
// C - Current Left
// D - Current Right
// E - Next Left
// F - Next Right

@property (strong, nonatomic) CALayer *layerA;
@property (strong, nonatomic) CALayer *layerB;
@property (strong, nonatomic) CALayer *layerC;
@property (strong, nonatomic) CALayer *layerD;
@property (strong, nonatomic) CALayer *layerE;
@property (strong, nonatomic) CALayer *layerF;

@end
