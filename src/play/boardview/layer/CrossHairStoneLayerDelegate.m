// -----------------------------------------------------------------------------
// Copyright 2011-2014 Patrick Näf (herzbube@herzbube.ch)
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
// -----------------------------------------------------------------------------


// Project includes
#import "CrossHairStoneLayerDelegate.h"
#import "BoardViewCGLayerCache.h"
#import "BoardViewDrawingHelper.h"
#import "../../model/BoardViewMetrics.h"
#import "../../../go/GoBoardPosition.h"
#import "../../../go/GoGame.h"
#import "../../../go/GoPlayer.h"
#import "../../../go/GoPoint.h"
#import "../../../go/GoVertex.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private properties for
/// CrossHairStoneLayerDelegate.
// -----------------------------------------------------------------------------
@interface CrossHairStoneLayerDelegate()
/// @brief Refers to the GoPoint object that marks the focus of the cross-hair.
@property(nonatomic, assign) GoPoint* crossHairPoint;
/// @brief Store drawing rectangle between notify:eventInfo:() and
/// drawLayer:inContext:(), and also between drawing cycles.
@property(nonatomic, assign) CGRect drawingRect;
/// @brief Store dirty rect between notify:eventInfo:() and drawLayer().
@property(nonatomic, assign) CGRect dirtyRect;
@end


@implementation CrossHairStoneLayerDelegate

// -----------------------------------------------------------------------------
/// @brief Initializes a CrossHairStoneLayerDelegate object.
///
/// @note This is the designated initializer of CrossHairStoneLayerDelegate.
// -----------------------------------------------------------------------------
- (id) initWithTile:(id<Tile>)tile metrics:(BoardViewMetrics*)metrics
{
  // Call designated initializer of superclass (BoardViewLayerDelegateBase)
  self = [super initWithTile:tile metrics:metrics];
  if (! self)
    return nil;
  self.crossHairPoint = nil;
  self.drawingRect = CGRectZero;
  self.dirtyRect = CGRectZero;
  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this CrossHairStoneLayerDelegate
/// object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  // There are times when no CrossHairStoneLayerDelegate instances are around
  // to react to events that invalidate the cached CGLayer, so the cached
  // CGLayer will inevitably become out-of-date. To prevent this, we invalidate
  // the CGLayer *NOW*.
  [self invalidateLayer];
  self.crossHairPoint = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Invalidates stone layers.
// -----------------------------------------------------------------------------
- (void) invalidateLayer
{
  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  [cache invalidateLayerOfType:CrossHairStoneLayerType];
}

// -----------------------------------------------------------------------------
/// @brief Invalidates the drawing rectangle.
// -----------------------------------------------------------------------------
- (void) invalidateDrawingRect
{
  self.drawingRect = CGRectZero;
}

// -----------------------------------------------------------------------------
/// @brief Invalidates the dirty rectangle.
// -----------------------------------------------------------------------------
- (void) invalidateDirtyRect
{
  self.dirtyRect = CGRectZero;
}

// -----------------------------------------------------------------------------
/// @brief BoardViewLayerDelegate method.
// -----------------------------------------------------------------------------
- (void) notify:(enum BoardViewLayerDelegateEvent)event eventInfo:(id)eventInfo
{
  switch (event)
  {
    case BVLDEventCrossHairChanged:
    {
      // Assume that we won't draw the stone and reset the property
      self.crossHairPoint = nil;

      GoPoint* crossHairPoint = eventInfo;
      CGRect oldDrawingRect = self.drawingRect;
      CGRect newDrawingRect = [self calculateDrawingRectangleForCrossHairPoint:crossHairPoint];
      // We need to compare the drawing rectangles, not the dirty rects. For
      // instance, if newDrawingRect is empty, but oldDrawingRect is not, this
      // means that we need to draw to clear the stone from the previous drawing
      // cycle. The old and the new dirty rects, however, are the same, so it's
      // clear that we can't just compare those.
      if (! CGRectEqualToRect(oldDrawingRect, newDrawingRect))
      {
        self.drawingRect = newDrawingRect;
        if (CGRectIsEmpty(oldDrawingRect))
          self.dirtyRect = newDrawingRect;
        else if (CGRectIsEmpty(newDrawingRect))
          self.dirtyRect = oldDrawingRect;
        else
          self.dirtyRect = CGRectUnion(oldDrawingRect, newDrawingRect);
        self.dirty = true;
        // Remember the point where we are going to draw the stone
        if (! CGRectIsEmpty(newDrawingRect))
          self.crossHairPoint = crossHairPoint;
      }
      break;
    }
    default:
    {
      break;
    }
  }
}

// -----------------------------------------------------------------------------
/// @brief BoardViewLayerDelegate method.
// -----------------------------------------------------------------------------
- (void) drawLayer
{
  if (self.dirty)
  {
    self.dirty = false;
    if (CGRectIsEmpty(self.dirtyRect))
      [self.layer setNeedsDisplay];
    else
      [self.layer setNeedsDisplayInRect:self.dirtyRect];
    [self invalidateDirtyRect];
  }
}

// -----------------------------------------------------------------------------
/// @brief CALayer delegate method.
// -----------------------------------------------------------------------------
- (void) drawLayer:(CALayer*)layer inContext:(CGContextRef)context
{
  // If we haven't remembered the cross-hair point this means that we won't
  // draw the stone (probably beause we are clearing a stone from a previous
  // drawing cycle). We can abort here, which will result in an empty layer.
  if (! self.crossHairPoint)
    return;

  BoardViewCGLayerCache* cache = [BoardViewCGLayerCache sharedCache];
  CGLayerRef blackStoneLayer = [cache layerOfType:BlackStoneLayerType];
  if (! blackStoneLayer)
  {
    blackStoneLayer = CreateStoneLayerWithImage(context, stoneBlackImageResource, self.boardViewMetrics);
    [cache setLayer:blackStoneLayer ofType:BlackStoneLayerType];
    CGLayerRelease(blackStoneLayer);
  }
  CGLayerRef whiteStoneLayer = [cache layerOfType:WhiteStoneLayerType];
  if (! whiteStoneLayer)
  {
    whiteStoneLayer = CreateStoneLayerWithImage(context, stoneWhiteImageResource, self.boardViewMetrics);
    [cache setLayer:whiteStoneLayer ofType:WhiteStoneLayerType];
    CGLayerRelease(whiteStoneLayer);
  }
  CGLayerRef crossHairStoneLayer = [cache layerOfType:CrossHairStoneLayerType];
  if (! crossHairStoneLayer)
  {
    crossHairStoneLayer = CreateStoneLayerWithImage(context, stoneCrosshairImageResource, self.boardViewMetrics);
    [cache setLayer:crossHairStoneLayer ofType:CrossHairStoneLayerType];
    CGLayerRelease(crossHairStoneLayer);
  }

  CGLayerRef stoneLayer;
  if (self.crossHairPoint.hasStone)
    stoneLayer = crossHairStoneLayer;
  else
  {
    GoBoardPosition* boardPosition = [GoGame sharedGame].boardPosition;
    if (boardPosition.currentPlayer.isBlack)
      stoneLayer = blackStoneLayer;
    else
      stoneLayer = whiteStoneLayer;
  }

  CGRect tileRect = [BoardViewDrawingHelper canvasRectForTile:self.tile
                                                      metrics:self.boardViewMetrics];
  [BoardViewDrawingHelper drawLayer:stoneLayer
                        withContext:context
                    centeredAtPoint:self.crossHairPoint
                     inTileWithRect:tileRect
                        withMetrics:self.boardViewMetrics];
}

// -----------------------------------------------------------------------------
/// @brief Returns a rectangle in which to draw the stone centered the specified
/// cross-hair point.
///
/// Returns CGRectZero if the stone is not located on this tile.
// -----------------------------------------------------------------------------
- (CGRect) calculateDrawingRectangleForCrossHairPoint:(GoPoint*)crossHairPoint
{
  if (! crossHairPoint)
    return CGRectZero;
  CGRect tileRect = [BoardViewDrawingHelper canvasRectForTile:self.tile
                                                      metrics:self.boardViewMetrics];
  CGRect stoneRect = [BoardViewDrawingHelper canvasRectForStoneAtPoint:crossHairPoint
                                                               metrics:self.boardViewMetrics];
  CGRect drawingRect = CGRectIntersection(tileRect, stoneRect);
  if (CGRectIsNull(drawingRect))
  {
    drawingRect = CGRectZero;
  }
  else
  {
    drawingRect = [BoardViewDrawingHelper drawingRectFromCanvasRect:drawingRect
                                                     inTileWithRect:tileRect];
  }
  return drawingRect;
}

@end