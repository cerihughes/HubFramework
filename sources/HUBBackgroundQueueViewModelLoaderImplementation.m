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

#import "HUBBackgroundQueueViewModelLoaderImplementation.h"

#import "HUBUtilities.h"

@interface HUBBackgroundQueueViewModelLoaderImplementation () <HUBViewModelLoaderDelegate>

@property (nonatomic, strong, readonly) dispatch_queue_t dispatchQueue;
@property (nonatomic, strong, readonly) id<HUBViewModelLoaderWithActions> viewModelLoader;

@end

@implementation HUBBackgroundQueueViewModelLoaderImplementation

@synthesize delegate = _delegate;

- (instancetype)initWithDispatchQueue:(dispatch_queue_t)dispatchQueue viewModelLoader:(id<HUBViewModelLoaderWithActions>)viewModelLoader
{
    self = [super init];
    if (self) {
        _dispatchQueue = dispatchQueue;
        _viewModelLoader = viewModelLoader;
        _viewModelLoader.delegate = self;
    }
    return self;
}

#pragma mark - HUBViewModelLoaderWithActions

- (nullable id<HUBActionPerformer>)actionPerformer
{
    return self.viewModelLoader.actionPerformer;
}

- (void)setActionPerformer:(nullable id<HUBActionPerformer>)actionPerformer
{
    self.viewModelLoader.actionPerformer = actionPerformer;
}

- (id<HUBViewModel>)initialViewModel
{
    return self.viewModelLoader.initialViewModel;
}

- (BOOL)isLoading
{
    return self.viewModelLoader.isLoading;
}

- (void)loadViewModel
{
    dispatch_async(self.dispatchQueue, ^{
        [self.viewModelLoader loadViewModel];
    });
}

- (void)reloadViewModel
{
    dispatch_async(self.dispatchQueue, ^{
        [self.viewModelLoader reloadViewModel];
    });
}

- (void)loadNextPageForCurrentViewModel
{
    dispatch_async(self.dispatchQueue, ^{
        [self.viewModelLoader loadNextPageForCurrentViewModel];
    });
}

#pragma mark - HUBViewModelLoaderDelegate

- (void)viewModelLoader:(id<HUBViewModelLoader>)viewModelLoader didLoadViewModel:(id<HUBViewModel>)viewModel
{
    HUBPerformOnMainQueue(^{
        [self.delegate viewModelLoader:self didLoadViewModel:viewModel];
    });
}

- (void)viewModelLoader:(id<HUBViewModelLoader>)viewModelLoader didFailLoadingWithError:(NSError *)error
{
    HUBPerformOnMainQueue(^{
        [self.delegate viewModelLoader:self didFailLoadingWithError:error];
    });
}

@end
