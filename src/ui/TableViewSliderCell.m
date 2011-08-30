// -----------------------------------------------------------------------------
// Copyright 2011 Patrick Näf (herzbube@herzbube.ch)
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
#import "TableViewSliderCell.h"
#import "UIColorAdditions.h"


// -----------------------------------------------------------------------------
/// @brief Class extension with private methods for TableViewSliderCell.
// -----------------------------------------------------------------------------
@interface TableViewSliderCell()
/// @name Initialization and deallocation
//@{
- (id) initWithReuseIdentifier:(NSString*)reuseIdentifier;
- (void) dealloc;
- (void) setupCell;
- (void) setupContentView;
//@}
/// @name Action methods
//@{
- (void) sliderValueChanged:(UISlider*)sender;
//@}
/// @name Other methods
//@{
- (void) updateValueLabel;
//@}
/// @name Re-declaration of properties to make them readwrite privately
//@{
@property(readwrite, retain) UILabel* descriptionLabel;
@property(readwrite, retain) UILabel* valueLabel;
@property(readwrite, retain) UISlider* slider;
@property(readwrite, retain) id delegate;
@property(readwrite) SEL delegateActionValueDidChange;
@property(readwrite) SEL delegateActionSliderValueDidChange;
//@}
@end


@implementation TableViewSliderCell

@synthesize descriptionLabel;
@synthesize valueLabel;
@synthesize slider;
@synthesize value;
@synthesize delegate;
@synthesize delegateActionValueDidChange;
@synthesize delegateActionSliderValueDidChange;


// Values determined experimentally by debugging a default UITableViewCell
static const int distanceFromEdgeHorizontal = 10;
static const int distanceFromEdgeVertical = 11;
// Spacing between UI elements (values determined experimentally in
// Interface Builder)
static const int spacingHorizontal = 8;
static const int spacingVertical = 8;
// UI elements sizes (values also from IB)
static const int labelHeight = 21;
static const int sliderHeight = 23;
// Arbitrary value that hopefully leaves enough space for the value label
static const int descriptionLabelWidth = 230;


// -----------------------------------------------------------------------------
/// @brief Convenience constructor. Creates a TableViewSliderCell instance with
/// reuse identifier @a reuseIdentifier.
// -----------------------------------------------------------------------------
+ (TableViewSliderCell*) cellWithReuseIdentifier:(NSString*)reuseIdentifier
{
  TableViewSliderCell* cell = [[TableViewSliderCell alloc] initWithReuseIdentifier:reuseIdentifier];
  if (cell)
    [cell autorelease];
  return cell;
}

// -----------------------------------------------------------------------------
/// @brief Initializes a TableViewSliderCell object with reuse identifier
/// @a reuseIdentifier.
///
/// @note This is the designated initializer of TableViewSliderCell.
// -----------------------------------------------------------------------------
- (id) initWithReuseIdentifier:(NSString*)reuseIdentifier
{
  // Call designated initializer of superclass (UITableViewCell)
  self = [super initWithStyle:UITableViewCellStyleDefault
              reuseIdentifier:reuseIdentifier];
  if (! self)
    return nil;

  [self setupCell];
  [self setupContentView];
  [slider addTarget:self action:@selector(sliderValueChanged:) forControlEvents:UIControlEventValueChanged];

  // TODO: instead of duplicating code from the setter, we should invoke the
  // setter (self.value = ...), but we need to be sure that it does not update
  // because of its old/new value check
  int newValue = self.slider.minimumValue;
  value = newValue;
  self.slider.value = newValue;
  [self updateValueLabel];

  return self;
}

// -----------------------------------------------------------------------------
/// @brief Deallocates memory allocated by this TableViewSliderCell object.
// -----------------------------------------------------------------------------
- (void) dealloc
{
  self.descriptionLabel = nil;
  self.valueLabel = nil;
  self.slider = nil;
  [super dealloc];
}

// -----------------------------------------------------------------------------
/// @brief Sets up cell attributes that are not related to the content view.
// -----------------------------------------------------------------------------
- (void) setupCell
{
  // The cell should never appear selected, instead we want the slider
  // to be the active element
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

// -----------------------------------------------------------------------------
/// @brief Sets up the content view with subviews for all UI elements in this
/// cell.
// -----------------------------------------------------------------------------
- (void) setupContentView
{
  // self.contentView still thinks it has the entire table view width, but in a
  // table view with grouped style the available width will be less because the
  // cell is set off from the view edges both on the left and the right
  // -> through debugging we know that the offset happens to be the default
  //    indentation width
  // -> this is probably not a coincidence, so we boldly use this indentation
  //    width for our calculations
  int contentViewWidth = self.contentView.bounds.size.width - (2 * self.indentationWidth);

  assert(descriptionLabelWidth < contentViewWidth);
  CGRect descriptionLabelRect = CGRectMake(distanceFromEdgeHorizontal, distanceFromEdgeVertical, descriptionLabelWidth, labelHeight);
  descriptionLabel = [[UILabel alloc] initWithFrame:descriptionLabelRect];  // no autorelease, property is retained
  descriptionLabel.tag = SliderCellDescriptionLabelTag;
  descriptionLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
  descriptionLabel.textAlignment = UITextAlignmentLeft;
  descriptionLabel.textColor = [UIColor blackColor];
  [self.contentView addSubview:descriptionLabel];

  int valueLabelX = descriptionLabelRect.origin.x + descriptionLabelRect.size.width + spacingHorizontal;
  int valueLabelY = descriptionLabelRect.origin.y;
  int valueLabelWidth = contentViewWidth - valueLabelX - distanceFromEdgeHorizontal;
  assert(valueLabelWidth > 0);
  CGRect valueLabelRect = CGRectMake(valueLabelX, valueLabelY, valueLabelWidth, labelHeight);
  valueLabel = [[UILabel alloc] initWithFrame:valueLabelRect];  // no autorelease, property is retained
  valueLabel.tag = SliderCellValueLabelTag;
  valueLabel.font = [UIFont systemFontOfSize:[UIFont labelFontSize]];
  valueLabel.textAlignment = UITextAlignmentRight;
  valueLabel.textColor = [UIColor slateBlueColor];
  [self.contentView addSubview:valueLabel];

  int sliderX = descriptionLabelRect.origin.x;
  int sliderY = descriptionLabelRect.origin.y + descriptionLabelRect.size.height + spacingVertical;
  int sliderWidth = valueLabelX + valueLabelWidth - sliderX;
  CGRect sliderRect = CGRectMake(sliderX, sliderY, sliderWidth, sliderHeight);
  slider = [[UISlider alloc] initWithFrame: sliderRect];  // no autorelease, property is retained
  slider.tag = SliderCellSliderTag;
  slider.continuous = YES;
  [self.contentView addSubview:slider];
}

// -----------------------------------------------------------------------------
/// @brief Returns the row height for TableViewSliderCell objects.
// -----------------------------------------------------------------------------
+ (CGFloat) rowHeightInTableView:(UITableView*)tableView
{
  static CGFloat rowHeight = 0;
  if (0 == rowHeight)
  {
    rowHeight = 2 * distanceFromEdgeVertical + labelHeight + spacingVertical + sliderHeight;
  }
  return rowHeight;
}

// -----------------------------------------------------------------------------
/// @brief Updates the integer value of this cell to @a newValue.
///
/// This method also updates the slider's value, so be sure to adjust the
/// slider's minimum/maximum values to accomodate @a newValue before invoking
/// this method.
// -----------------------------------------------------------------------------
- (void) setValue:(int)newValue
{
  if (value == newValue)
    return;
  value = newValue;
  self.slider.value = newValue;
  [self updateValueLabel];
  if ([self.delegate respondsToSelector:self.delegateActionValueDidChange])
    [self.delegate performSelector:self.delegateActionValueDidChange withObject:self];
}

// -----------------------------------------------------------------------------
/// @brief Update value label to display the slider's new value.
// -----------------------------------------------------------------------------
- (void) sliderValueChanged:(UISlider*)sender
{
  // This check also has the benefit that the value label is not updated
  // unnecessarily many times for fraction changes that we are not interested
  // in
  int newValue = sender.value;
  if (value == newValue)
    return;
  self.value = newValue;
  if ([self.delegate respondsToSelector:self.delegateActionSliderValueDidChange])
    [self.delegate performSelector:self.delegateActionSliderValueDidChange withObject:self];
}

// -----------------------------------------------------------------------------
/// @brief Updates value label to display the slider's current value (only the
/// integer part).
// -----------------------------------------------------------------------------
- (void) updateValueLabel
{
  int intValue = slider.value;
  self.valueLabel.text = [NSString stringWithFormat:@"%d", intValue];
}

// -----------------------------------------------------------------------------
/// @brief Configures this cell with @a delegate and selectors for methods to
/// invoke when the cell's integer value changes.
// -----------------------------------------------------------------------------
- (void) setDelegate:(id)aDelegate actionValueDidChange:(SEL)action1 actionSliderValueDidChange:(SEL)action2
{
  self.delegate = aDelegate;
  self.delegateActionValueDidChange = action1;
  self.delegateActionSliderValueDidChange = action2;
}

@end
