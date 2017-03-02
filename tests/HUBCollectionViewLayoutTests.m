/*
 *  Copyright (c) 2016 Spotify AB.
 *
 *  Licensed to the Apache Software Foundation (ASF) under one
 *  or more contributor license agreements.  See the NOTICE file
 *  distributed with this work for additional information
 *  regarding copyright ownership.  The ASF licenses this file
 *  to you under the Apache License, Version 2.0 (the
 *  "License"); you may not use this file except in compliance
 *  with the License.  You may obtain a copy of the License at
 *
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing,
 *  software distributed under the License is distributed on an
 *  "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 *  KIND, either express or implied.  See the License for the
 *  specific language governing permissions and limitations
 *  under the License.
 */

#import <XCTest/XCTest.h>

#import "HUBIdentifier.h"
#import "HUBComponentRegistryImplementation.h"
#import "HUBCollectionViewLayout.h"
#import "HUBViewModelBuilderImplementation.h"
#import "HUBViewModelImplementation.h"
#import "HUBComponentLayoutManagerMock.h"
#import "HUBComponentMock.h"
#import "HUBComponentFactoryMock.h"
#import "HUBComponentModelBuilder.h"
#import "HUBJSONSchemaRegistryImplementation.h"
#import "HUBJSONSchemaImplementation.h"
#import "HUBComponentDefaults.h"
#import "HUBComponentFallbackHandlerMock.h"
#import "HUBIconImageResolverMock.h"
#import "HUBCollectionViewMock.h"
#import "HUBViewModelDiff.h"
#import "HUBTestUtilities.h"

@interface HUBCollectionViewLayoutTests : XCTestCase

@property (nonatomic) CGSize collectionViewSize;
@property (nonatomic, strong) HUBComponentMock *compactComponent;
@property (nonatomic, strong) HUBIdentifier *compactComponentIdentifier;

@property (nonatomic, strong) HUBComponentMock *centeredComponent;
@property (nonatomic, strong) HUBIdentifier *centeredComponentIdentifier;

@property (nonatomic, strong) HUBComponentMock *fullWidthComponent;
@property (nonatomic, strong) HUBIdentifier *fullWidthComponentIdentifier;

@property (nonatomic, strong) HUBComponentFactoryMock *componentFactory;
@property (nonatomic, strong) HUBComponentRegistryImplementation *componentRegistry;
@property (nonatomic, strong) HUBComponentLayoutManagerMock *componentLayoutManager;
@property (nonatomic, strong) HUBViewModelBuilderImplementation *viewModelBuilder;

@property (nonatomic, strong) HUBCollectionViewLayout * layout;

@end

@implementation HUBCollectionViewLayoutTests

#pragma mark - XCTestCase

- (void)setUp
{
    [super setUp];
    
    self.collectionViewSize = CGSizeMake(320, 400);
    
    NSString * const componentNamespace = @"namespace";
    NSString * const compactComponentName = @"compact";
    
    self.compactComponent = [HUBComponentMock new];
    [self.compactComponent.layoutTraits addObject:HUBComponentLayoutTraitCompactWidth];
    self.compactComponent.preferredViewSize = CGSizeMake(100, 100);
    self.compactComponentIdentifier = [[HUBIdentifier alloc] initWithNamespace:componentNamespace name:compactComponentName];
    
    self.fullWidthComponent = [HUBComponentMock new];
    [self.fullWidthComponent.layoutTraits addObject:HUBComponentLayoutTraitFullWidth];
    self.fullWidthComponent.preferredViewSize = CGSizeMake(self.collectionViewSize.width, 100);
    self.fullWidthComponentIdentifier = [[HUBIdentifier alloc] initWithNamespace:componentNamespace name:@"fullWidth"];

    self.centeredComponent = [HUBComponentMock new];
    [self.centeredComponent.layoutTraits addObject:HUBComponentLayoutTraitCentered];
    self.centeredComponent.preferredViewSize = CGSizeMake(50, 50);
    self.centeredComponentIdentifier = [[HUBIdentifier alloc] initWithNamespace:componentNamespace name:@"centered"];
    
    self.componentFactory = [[HUBComponentFactoryMock alloc] initWithComponents:@{
        self.compactComponentIdentifier.namePart: self.compactComponent,
        self.fullWidthComponentIdentifier.namePart: self.fullWidthComponent,
        self.centeredComponentIdentifier.namePart: self.centeredComponent
    }];
    
    HUBComponentDefaults * const componentDefaults = [[HUBComponentDefaults alloc] initWithComponentNamespace:componentNamespace
                                                                                                componentName:compactComponentName
                                                                                            componentCategory:@"category"];
    
    id<HUBComponentFallbackHandler> const componentFallbackHandler = [[HUBComponentFallbackHandlerMock alloc] initWithComponentDefaults:componentDefaults];
    HUBJSONSchemaRegistryImplementation * const JSONSchemaRegistry = [[HUBJSONSchemaRegistryImplementation alloc] initWithComponentDefaults:componentDefaults
                                                                                                                          iconImageResolver:nil];
    
    self.componentRegistry = [[HUBComponentRegistryImplementation alloc] initWithFallbackHandler:componentFallbackHandler
                                                                               componentDefaults:componentDefaults
                                                                              JSONSchemaRegistry:JSONSchemaRegistry
                                                                               iconImageResolver:nil];
    
    [self.componentRegistry registerComponentFactory:self.componentFactory forNamespace:componentNamespace];
    
    self.componentLayoutManager = [HUBComponentLayoutManagerMock new];

    self.layout = [[HUBCollectionViewLayout alloc] initWithComponentRegistry:self.componentRegistry
                                                      componentLayoutManager:self.componentLayoutManager];

    id<HUBIconImageResolver> const iconImageResolver = [HUBIconImageResolverMock new];
    
    id<HUBJSONSchema> const JSONSchema = [[HUBJSONSchemaImplementation alloc] initWithComponentDefaults:componentDefaults
                                                                                      iconImageResolver:iconImageResolver];
    
    self.viewModelBuilder = [[HUBViewModelBuilderImplementation alloc] initWithJSONSchema:JSONSchema
                                                                        componentDefaults:componentDefaults
                                                                        iconImageResolver:iconImageResolver];
}

- (void)tearDown
{
    self.compactComponent = nil;
    self.compactComponentIdentifier = nil;
    self.centeredComponent = nil;
    self.centeredComponentIdentifier = nil;
    self.fullWidthComponent = nil;
    self.fullWidthComponentIdentifier = nil;
    self.componentFactory = nil;
    self.componentRegistry = nil;
    self.componentLayoutManager = nil;
    self.viewModelBuilder = nil;
    self.layout = nil;

    [super tearDown];
}

#pragma mark - Tests

- (void)testTopLeftContentEdgeMargins
{
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    
    CGFloat const edgeMargin = 20;
    CGSize const componentSize = self.compactComponent.preferredViewSize;
    self.componentLayoutManager.contentEdgeMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(edgeMargin);
    
    [self computeLayoutWithHeaderMargin:NO];
    
    NSIndexPath * const componentIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect const componentViewFrame = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath].frame;
    CGRect const expectedComponentViewFrame = CGRectMake(edgeMargin, edgeMargin, componentSize.width, componentSize.height);
    
    XCTAssertTrue(CGRectEqualToRect(componentViewFrame, expectedComponentViewFrame));
}

- (void)testRightContentEdgeMargin
{
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    
    self.compactComponent.preferredViewSize = CGSizeMake(self.collectionViewSize.width, 50);
    
    CGFloat const edgeMargin = 20;
    self.componentLayoutManager.contentEdgeMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(edgeMargin);
    
    [self computeLayoutWithHeaderMargin:NO];
    
    NSIndexPath * const componentIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect const componentViewFrame = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath].frame;
    CGRect const expectedComponentViewFrame = CGRectMake(
        edgeMargin,
        edgeMargin,
        self.compactComponent.preferredViewSize.width - edgeMargin * 2,
        self.compactComponent.preferredViewSize.height
    );
    
    XCTAssertTrue(CGRectEqualToRect(componentViewFrame, expectedComponentViewFrame));
}

- (void)testVerticalMarginToHeaderComponent
{
    self.viewModelBuilder.headerComponentModelBuilder.componentName = self.fullWidthComponentIdentifier.namePart;
    [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier];
    
    CGFloat const headerMargin = 30;
    CGSize const componentSize = self.fullWidthComponent.preferredViewSize;
    self.componentLayoutManager.headerMarginsForLayoutTraits[self.fullWidthComponent.layoutTraits] = @(headerMargin);
    
    [self computeLayoutWithHeaderMargin:YES];
    
    NSIndexPath * const componentIndexPath = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect const componentViewFrame = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath].frame;
    CGRect const expectedComponentViewFrame = CGRectMake(0, headerMargin + componentSize.height, componentSize.width, componentSize.height);
    
    XCTAssertTrue(CGRectEqualToRect(componentViewFrame, expectedComponentViewFrame));
}

- (void)testCollectionViewContentSize
{
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.centeredComponentIdentifier];

    CGFloat const bottomContentEdgeMargin = 40;
    CGSize const compactComponentSize = self.compactComponent.preferredViewSize;
    CGSize const fullWidthComponentSize = self.fullWidthComponent.preferredViewSize;
    CGSize const centeredComponentSize = self.centeredComponent.preferredViewSize;
    self.componentLayoutManager.contentEdgeMarginsForLayoutTraits[self.centeredComponent.layoutTraits] = @(bottomContentEdgeMargin);
    
    [self computeLayoutWithHeaderMargin:NO];
    
    CGSize const expectedCollectionViewContentSize = CGSizeMake(
        self.collectionViewSize.width,
        compactComponentSize.height * 2 + fullWidthComponentSize.height * 2 + centeredComponentSize.height + bottomContentEdgeMargin
    );
    
    XCTAssertTrue(CGSizeEqualToSize(expectedCollectionViewContentSize, self.layout.collectionViewContentSize));
}

- (void)testComponentMovedToNewRowIfWidthExceedsAvailableSpace
{
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];

    CGFloat const componentVerticalMargin = 20;
    CGFloat const componentContentEdgeMargin = 15;
    CGSize const componentSize = self.compactComponent.preferredViewSize;
    self.componentLayoutManager.verticalComponentMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(componentVerticalMargin);
    self.componentLayoutManager.contentEdgeMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(componentContentEdgeMargin);

    [self computeLayoutWithHeaderMargin:NO];

    // H:|-15-[c1(100)][c2(100)][c3(100)]-15-|
    // but total width (330) > collectionView width (320) so component 3 have to be moved to a new row

    NSIndexPath * const componentIndexPath = [NSIndexPath indexPathForItem:2 inSection:0];
    CGRect const componentViewFrame = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath].frame;
    CGRect const expectedComponentViewFrame = CGRectMake(componentContentEdgeMargin,
                                                         componentContentEdgeMargin + componentSize.height + componentVerticalMargin,
                                                         componentSize.width,
                                                         componentSize.height);

    XCTAssertTrue(CGRectEqualToRect(componentViewFrame, expectedComponentViewFrame));
}

- (void)testComponentMovedToNewRowIfItsHorizontalMarginIsBiggerThanCollectionViewWidth
{
    [self addBodyComponentWithIdentifier:self.centeredComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.compactComponentIdentifier];

    CGFloat const componentVerticalMargin = 20;
    CGSize const compactComponentSize = self.compactComponent.preferredViewSize;
    CGSize const centeredComponentSize = self.centeredComponent.preferredViewSize;

    self.componentLayoutManager.verticalComponentMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(componentVerticalMargin);
    self.componentLayoutManager.horizontalComponentMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(CGFLOAT_MAX);

    [self computeLayoutWithHeaderMargin:NO];

    // Check that the second component is on new row because it is not centered and the first one is
    NSIndexPath * const secondComponentIndexPath = [NSIndexPath indexPathForItem:1 inSection:0];
    CGRect const secondComponentViewFrame = [self.layout layoutAttributesForItemAtIndexPath:secondComponentIndexPath].frame;
    CGRect const expectedFrameForSecondComponent = CGRectMake(0, centeredComponentSize.height + componentVerticalMargin, compactComponentSize.width, compactComponentSize.height);
    XCTAssertTrue(CGRectEqualToRect(secondComponentViewFrame, expectedFrameForSecondComponent));
}

- (void)testComponentOrigins
{
    [self addBodyComponentWithIdentifier:self.centeredComponentIdentifier];
    [self addBodyComponentWithIdentifier:self.centeredComponentIdentifier];

    CGFloat const componentVerticalMargin = 20;

    self.componentLayoutManager.verticalComponentMarginsForLayoutTraits[self.compactComponent.layoutTraits] = @(componentVerticalMargin);
    self.componentLayoutManager.verticalComponentMarginsForLayoutTraits[self.centeredComponent.layoutTraits] = @(componentVerticalMargin);
    NSArray *componentsLayoutTraits = @[self.centeredComponent.layoutTraits, self.centeredComponent.layoutTraits];
    self.componentLayoutManager.horizontalComponentOffsetsForArrayOfLayoutTraits[componentsLayoutTraits] = @(110);

    [self computeLayoutWithHeaderMargin:NO];

    NSIndexPath * const componentIndexPath1 = [NSIndexPath indexPathForItem:0 inSection:0];
    CGRect const componentViewFrame1 = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath1].frame;
    HUBAssertEqualFloatValues(componentViewFrame1.origin.x, 110);
    
    NSIndexPath * const componentIndexPath2 = [NSIndexPath indexPathForItem:1 inSection:0];
    CGRect const componentViewFrame2 = [self.layout layoutAttributesForItemAtIndexPath:componentIndexPath2].frame;
    HUBAssertEqualFloatValues(componentViewFrame2.origin.x, 160);
}

- (void)testProposedContentOffsetWithoutRecomputing
{
    for (NSUInteger i = 0; i < 30; i++) {
        [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier];
    }

    [self computeLayoutWithHeaderMargin:NO];

    CGPoint const proposedOffset = CGPointMake(0.0, 1200.0);
    HUBAssertEqualFloatValues([self.layout targetContentOffsetForProposedContentOffset:proposedOffset].y, proposedOffset.y);
}

- (void)testProposedContentOffsetForInitiallyAddedComponents
{
    CGRect const collectionViewFrame = {.origin = CGPointZero, .size = self.collectionViewSize};
    HUBCollectionViewMock * const collectionView = [[HUBCollectionViewMock alloc] initWithFrame:collectionViewFrame
                                                                           collectionViewLayout:self.layout];
    
    collectionView.mockedIndexPathsForVisibleItems = @[];
    
    id<HUBViewModel> const viewModelA = [self.viewModelBuilder build];
    [self.layout computeForCollectionViewSize:collectionViewFrame.size viewModel:viewModelA diff:nil addHeaderMargin:YES];
    
    for (NSUInteger componentIndex = 0; componentIndex < 20; componentIndex++) {
        NSString * const componentIdentifier = [NSString stringWithFormat:@"%@", @(componentIndex)];
        [self.viewModelBuilder builderForBodyComponentModelWithIdentifier:componentIdentifier].title = @"Component";
    }
    
    id<HUBViewModel> const viewModelB = [self.viewModelBuilder build];
    HUBViewModelDiff * const diff = [HUBViewModelDiff diffFromViewModel:viewModelA toViewModel:viewModelB];
    [self.layout computeForCollectionViewSize:collectionViewFrame.size viewModel:viewModelB diff:diff addHeaderMargin:YES];
    
    CGPoint const targetContentOffset = [self.layout targetContentOffsetForProposedContentOffset:CGPointZero];
    XCTAssertTrue(CGPointEqualToPoint(targetContentOffset, CGPointZero));
}

- (void)testProposedContentOffsetAfterRecomputing
{
    // Create an initial layout with 30 items
    for (NSUInteger i = 0; i < 30; i++) {
        [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier preferredIndex:i];
    }

    id<HUBViewModel> const viewModel = [self.viewModelBuilder build];

    CGRect const collectionViewFrame = {.origin = CGPointZero, .size = self.collectionViewSize};
    HUBCollectionViewMock * const collectionView = [[HUBCollectionViewMock alloc] initWithFrame:collectionViewFrame
                                                                           collectionViewLayout:self.layout];

    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:viewModel diff:nil addHeaderMargin:YES];

    // Currently, assume only index path 0-25 is on screen, and it's at the top (offset = 2500)
    NSIndexPath * const topmostIndexPath = [NSIndexPath indexPathForItem:25 inSection:0];
    collectionView.mockedIndexPathsForVisibleItems = @[topmostIndexPath];

    CGPoint const contentOffset = CGPointMake(0.0, 2500.0);
    collectionView.contentOffset = contentOffset;

    // Insert 2 items at start
    for (NSUInteger i = 0; i < 2; i++) {
        [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier preferredIndex:i];
    }

    // Remove 1st 12 items
    for (NSUInteger i = 0; i < 12; i++) {
        [self removeBodyComponentAtIndex:i];
    }

    id<HUBViewModel> const newViewModel = [self.viewModelBuilder build];
    HUBViewModelDiff * const diff = [HUBViewModelDiff diffFromViewModel:viewModel toViewModel:newViewModel];

    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:newViewModel diff:diff addHeaderMargin:YES];

    // With 10 less items (+2 - 12), the offset should now be 1500
    HUBAssertEqualFloatValues([self.layout targetContentOffsetForProposedContentOffset:contentOffset].y, 1500);
}

- (void)testProposedContentOffsetBeyondBounds
{
    CGRect const collectionViewFrame = {.origin = CGPointZero, .size = self.collectionViewSize};
    HUBCollectionViewMock * const collectionView = [[HUBCollectionViewMock alloc] initWithFrame:collectionViewFrame
                                                                           collectionViewLayout:self.layout];
    collectionView.contentInset = UIEdgeInsetsMake(27.0, 0.0, 34.0, 0.0);

    id<HUBViewModel> const firstViewModel = [self.viewModelBuilder build];
    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:firstViewModel diff:nil addHeaderMargin:YES];

    // Create 10 components, each of height 100
    for (NSUInteger i = 0; i < 10; i++) {
        [self addBodyComponentWithIdentifier:self.fullWidthComponentIdentifier preferredIndex:i];
    }

    id<HUBViewModel> const secondViewModel = [self.viewModelBuilder build];
    HUBViewModelDiff * const firstDiff = [HUBViewModelDiff diffFromViewModel:firstViewModel toViewModel:secondViewModel];

    collectionView.mockedIndexPathsForVisibleItems = @[[NSIndexPath indexPathForItem:9 inSection:0]];
    collectionView.contentOffset = CGPointMake(0.0, 400.0);
    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:secondViewModel diff:firstDiff addHeaderMargin:YES];

    CGFloat expectedOffset = 634; // Content size is 1000; collection view height is 400; bottom inset is 34.
    HUBAssertEqualFloatValues([self.layout targetContentOffsetForProposedContentOffset:collectionView.contentOffset].y, expectedOffset);

    // Remove all 10 components
    for (NSUInteger i = 0; i < 10; i++) {
        [self removeBodyComponentAtIndex:i];
    }

    id<HUBViewModel> const newViewModel = [self.viewModelBuilder build];
    HUBViewModelDiff * const secondDiff = [HUBViewModelDiff diffFromViewModel:secondViewModel toViewModel:newViewModel];

    collectionView.mockedIndexPathsForVisibleItems = @[[NSIndexPath indexPathForItem:9 inSection:0]];
    collectionView.contentOffset = CGPointZero;
    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:newViewModel diff:secondDiff addHeaderMargin:YES];

    expectedOffset = -27; // Top inset is 27
    HUBAssertEqualFloatValues([self.layout targetContentOffsetForProposedContentOffset:collectionView.contentOffset].y, expectedOffset);
}

#pragma mark - Utilities

- (void)addBodyComponentWithIdentifier:(HUBIdentifier *)componentIdentifier preferredIndex:(NSUInteger)preferredIndex
{
    NSString * const modelIdentifier = [NSUUID UUID].UUIDString;
    id<HUBComponentModelBuilder> componentBuilder = [self.viewModelBuilder builderForBodyComponentModelWithIdentifier:modelIdentifier];
    componentBuilder.componentName = componentIdentifier.namePart;
    componentBuilder.preferredIndex = @(preferredIndex);
}

- (void)addBodyComponentWithIdentifier:(HUBIdentifier *)componentIdentifier
{
    NSString * const modelIdentifier = [NSUUID UUID].UUIDString;
    [self.viewModelBuilder builderForBodyComponentModelWithIdentifier:modelIdentifier].componentName = componentIdentifier.namePart;
}

- (void)removeBodyComponentAtIndex:(NSUInteger)componentIndex
{
    NSArray<id<HUBComponentModelBuilder>> *childBuilders = [self.viewModelBuilder allBodyComponentModelBuilders];

    for (id<HUBComponentModelBuilder> builder in childBuilders) {
        if (builder.preferredIndex.unsignedIntegerValue == componentIndex) {
            [self.viewModelBuilder removeBuilderForBodyComponentModelWithIdentifier:builder.modelIdentifier];
            break;
        }
    }
}

- (void)computeLayoutWithHeaderMargin:(BOOL)addHeaderMargin
{
    id<HUBViewModel> const viewModel = [self.viewModelBuilder build];
    [self.layout computeForCollectionViewSize:self.collectionViewSize viewModel:viewModel diff:nil addHeaderMargin:addHeaderMargin];
}

@end
