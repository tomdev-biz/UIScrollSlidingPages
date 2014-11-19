//
//  TTSlidingPagesController.m
//  UIScrollViewSlidingPages
//
//  Created by Thomas Thorpe on 27/03/2013.
//  Copyright (c) 2013 Thomas Thorpe. All rights reserved.
//

/*
 Copyright (c) 2012 Tom Thorpe. All rights reserved.
 
 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE.
 */

#import "TTScrollSlidingPagesController.h"
#import "TTSlidingPage.h"

@implementation TTScrollSlidingPagesController

/**
 Initalises the control and sets all the default values for the user-settable properties.
 */
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        viewDidLoadHasBeenCalled = NO;

        self.triangleBackgroundColour = [UIColor blackColor];
        self.disableTitleScrollerShadow = NO;
        self.disableUIPageControl = NO;
        self.initialPageNumber = 0;
        self.pagingEnabled = YES;
        self.zoomOutAnimationDisabled = NO;
        self.hideStatusBarWhenScrolling = NO;
    }
    return self;
}

/**
 Initialse the top and bottom scrollers (but don't populate them with pages yet)
 */
- (void)viewDidLoad
{
    [super viewDidLoad];
    
    viewDidLoadHasBeenCalled = YES;
    
    int nextYPosition = 0;
    int pageDotsControlHeight = 0;
    if (!self.disableUIPageControl){
        //create and add the UIPageControl
        CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
        int statusBarHeight = MIN(statusBarFrame.size.height, statusBarFrame.size.width); // the height of the status bar will be the smaller value. Can't guarantee it's the height property because if the app starts in landscape sometimes the height is actually the width property :|
        pageDotsControlHeight = statusBarHeight;
        pageControl = [[UIPageControl alloc] initWithFrame:CGRectMake(0, nextYPosition, self.view.frame.size.width, pageDotsControlHeight)];
        pageControl.backgroundColor = [UIColor blackColor];
        pageControl.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        [pageControl addTarget:self action:@selector(pageControlChangedPage:) forControlEvents:UIControlEventValueChanged];
        [self.view addSubview:pageControl];
    }
    
    //set up the bottom scroller (for the content to go in)
    bottomScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height)];
    bottomScrollView.pagingEnabled = self.pagingEnabled;
    bottomScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
    bottomScrollView.showsVerticalScrollIndicator = NO;
    bottomScrollView.showsHorizontalScrollIndicator = NO;
    bottomScrollView.directionalLockEnabled = YES;
    bottomScrollView.delegate = self; //move the top scroller proportionally as you drag the bottom.
    bottomScrollView.alwaysBounceVertical = NO;
    [self.view addSubview:bottomScrollView];
}

-(void)viewDidAppear:(BOOL)animated{
    if (!viewDidAppearHasBeenCalled){
        viewDidAppearHasBeenCalled = YES;
        [self reloadPages];
    }
}

/**
 Goes through the datasource and finds all the pages, then populates the topScrollView and bottomScrollView with all the pages and headers.
 
 It clears any of the views in both scrollViews first, so if you need to reload all the pages with new data from the dataSource for some reason, you can call this method.
 */
-(void)reloadPages{
    if (self.dataSource == nil){
        [NSException raise:@"TTSlidingPagesController data source missing" format:@"There was no data source set for the TTSlidingPagesControlller. You must set the .dataSource property on TTSlidingPagesController to an object instance that implements TTSlidingPagesDataSource, also make sure you do this before the view will be loaded (so before you add it as a subview to any other view that is about to appear)"];
    }
    
    //remove any existing items from the subviews
    [bottomScrollView.subviews makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    //remove any existing items from the view hierarchy
    for (UIViewController* subViewController in self.childViewControllers){
        [subViewController willMoveToParentViewController:nil];
        [subViewController removeFromParentViewController];
    }
    
    //get the number of pages
    int numOfPages = [self.dataSource numberOfPagesForSlidingPagesViewController:self];
    
    //keep track of where next to put items in each scroller
    int nextXPosition = 0;
    
    //loop through each page and add it to the scroller
    for (int i=0; i<numOfPages; i++){
        //bottom scroller add-----
        //set the default width of the page
        int pageWidth = bottomScrollView.frame.size.width;
        //if the datasource implements the widthForPageOnSlidingPagesViewController:atIndex method, use it to override the width of the page
        if ([self.dataSource respondsToSelector:@selector(widthForPageOnSlidingPagesViewController:atIndex:)] ){
            pageWidth = [self.dataSource widthForPageOnSlidingPagesViewController:self atIndex:i];
        }
        
        TTSlidingPage *page = [self.dataSource pageForSlidingPagesViewController:self atIndex:i];//get the page
        if (page == nil || ![page isKindOfClass:[TTSlidingPage class]]){
            [NSException raise:@"TTScrollSlidingPagesController Wrong Page Content Type" format:@"TTScrollSlidingPagesController: Page contents should be instances of TTSlidingPage, one was returned that was either nil, or wasn't a TTSlidingPage. Make sure your pageForSlidingPagesViewController method in the datasource always returns a TTSlidingPage instance for each page requested."];
        }
        UIView *contentView = page.contentView;
        
        //make a container view (putting it inside a container view because if the contentView uses any autolayout it doesn't work well with the .transform property that the zoom animation uses. The container view shields it from this).
        UIView *containerView = [[UIView alloc] init];
        
        //put the container view in the right position, y is always 0, x is incremented with each item you add (it is a horizontal scroller).
        containerView.frame = CGRectMake(nextXPosition, 0, pageWidth, bottomScrollView.frame.size.height);
        nextXPosition = nextXPosition + containerView.frame.size.width;
        
        //put the content view inside the container view
        contentView.frame = CGRectMake(0, 0, pageWidth, bottomScrollView.frame.size.height);
        [containerView addSubview:contentView];
        
        //add the container view to the scroll view
        [bottomScrollView addSubview:containerView];
        
        
        if (page.contentViewController != nil){
            [self addChildViewController:page.contentViewController];
            [page.contentViewController didMoveToParentViewController:self];
        }
        
    }
    
    //now set the content size of the scroller to be as wide as nextXPosition (we can know that nextXPosition is also the width of the scroller)
    bottomScrollView.contentSize = CGSizeMake(nextXPosition, bottomScrollView.frame.size.height);
    
    int initialPage = self.initialPageNumber;
    
    if (!self.disableUIPageControl){
        //set the number of dots on the page control, and set the initial selected dot
        pageControl.numberOfPages = numOfPages;
        pageControl.currentPage = initialPage;
    }
    
    //scroll to the initialpage
    [self scrollToPage:initialPage animated:NO];
}


/**
 Gets number of the page currently displayed in the bottom scroller (zero based - so starting at 0 for the first page).
 
 @return Returns the number of the page currently displayed in the bottom scroller (zero based - so starting at 0 for the first page).
 */
-(int)getCurrentDisplayedPage{
    //sum through all the views until you get to a position that matches the offset then that's what page youre on (each view can be a different width)
    int page = 0;
    int currentXPosition = 0;
    while (currentXPosition <= bottomScrollView.contentOffset.x && currentXPosition < bottomScrollView.contentSize.width){
        currentXPosition += [self getWidthOfPage:page];
        
        if (currentXPosition <= bottomScrollView.contentOffset.x){
            page++;
        }
    }
    
    return page;
}

/**
 Gets the x position of the requested page in the bottom scroller. For example, if you ask for page 5, and page 5 starts at the contentOffset 520px in the bottom scroller, this will return 520.
 
 @param page The page number requested.
 @return Returns the x position of the requested page in the bottom scroller
 */
-(int)getXPositionOfPage:(int)page{
    //each view could in theory have a different width
    int currentTotal = 0;
    for (int curPage = 0; curPage < page; curPage++){
        currentTotal += [self getWidthOfPage:curPage];
    }
    
    return currentTotal;
}

/**
 Gets the width of a specific page in the bottom scroll view. Most of the time this will be the width of the scrollview itself, but if you have widthForPageOnSlidingPagesViewController implemented on the datasource it might be different - hence this method.
 
 @param page The page number requested.
 @return Returns the width of the page requested.
 */
-(int)getWidthOfPage:(int)page {
    int pageWidth = bottomScrollView.frame.size.width;
    if ([self.dataSource respondsToSelector:@selector(widthForPageOnSlidingPagesViewController:atIndex:)]){
        pageWidth = [self.dataSource widthForPageOnSlidingPagesViewController:self atIndex:page];
    }
    return pageWidth;
}

/**
 Gets the page based on an X position in the topScrollView. For example, if you pass in 100 and each topScrollView width is 50, then this would return page 2.
 
 @param page The X position in the topScrollView
 @return Returns the page. For example, if you pass in 100 and each topScrollView width is 50, then this would return page 2.
 */
-(int)getTopScrollViewPageForXPosition:(int)xPosition{
    return xPosition / self.titleScrollerItemWidth;
}

/**
 Scrolls the bottom scorller (content scroller) to a particular page number.
 
 @param page The page number to scroll to.
 @param animated Whether the scroll should be animated to move along to the page (YES) or just directly scroll to the page (NO)
 */
-(void)scrollToPage:(int)page animated:(BOOL)animated{
    //keep track of the current page (for the rotation if it ever happens)
    currentPageBeforeRotation = page;
    
    //scroll to the page
    [bottomScrollView setContentOffset: CGPointMake([self getXPositionOfPage:page],0) animated:animated];

    //update the pagedots pagenumber
    if (!self.disableUIPageControl){
        pageControl.currentPage = page;
    }
}

/**If YES, hides the status bar and shows the page dots.
 *If NO, shows the status bar and hides the page dots.
 But only if the self.hideStatusBarWhenScrolling property is set to YES, and the disableUIPageControl is NO.
 */
-(void)setStatusBarReplacedWithPageDots:(BOOL)statusBarHidden{
    if (self.hideStatusBarWhenScrolling && !self.disableUIPageControl){
        //hide the status bar and show the page dots control
        [[UIApplication sharedApplication] setStatusBarHidden:statusBarHidden withAnimation:UIStatusBarAnimationFade];
        float pageControlAlpha = statusBarHidden ? 1 : 0;
        [UIView animateWithDuration:0.3 animations:^{
            pageControl.alpha = pageControlAlpha;
        }];
    }
}


#pragma mark Some delegate methods for handling rotation.

-(void)didRotate{
    currentPageBeforeRotation = [self getCurrentDisplayedPage];
}


-(void)viewDidLayoutSubviews{
    //this will get called when the screen rotates, at which point we need to fix the frames of all the subviews to be the new correct x position horizontally. The autolayout mask will automatically change the width for us.
    //reposition the subviews and set the new contentsize width
    CGRect frame;
    int nextXPosition = 0;
    int page = 0;
    for (UIView *view in bottomScrollView.subviews) {
        view.transform = CGAffineTransformIdentity;
        frame = view.frame;
        frame.size.width = [self getWidthOfPage:page];
        frame.size.height = bottomScrollView.frame.size.height;
        frame.origin.x = nextXPosition;
        frame.origin.y = 0;
        page++;
        nextXPosition += frame.size.width;
        view.frame = frame;
    }
    bottomScrollView.contentSize = CGSizeMake(nextXPosition, bottomScrollView.frame.size.height);
    
    //set it back to the same page as it was before (the contentoffset will be different now the widths are different)
    int contentOffsetWidth = [self getXPositionOfPage:currentPageBeforeRotation];
    bottomScrollView.contentOffset = CGPointMake(contentOffsetWidth, 0);
    
}

#pragma mark UIScrollView delegate

-(void)scrollViewWillBeginDragging:(UIScrollView *)scrollView{
    [self setStatusBarReplacedWithPageDots:YES];
}


- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (bottomScrollView.subviews.count == 0){
        return; //there are no pages in the bottom scroll view so we couldn't have scrolled. This probably happened during a rotation before the pages had been created (E.g if the app starts in landscape mode)
    }

    // CHANGE - Adding scrollViewDidScroller method
    if([self.dataSource respondsToSelector:@selector(scrollViewDidScroller:)]) {
       [self.dataSource scrollViewDidScroller:scrollView];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView{
    int currentPage = [self getCurrentDisplayedPage];
    
    [self setStatusBarReplacedWithPageDots:NO];
    
    //store the page you were on so if you have a rotate event, or you come back to this view you know what page to start at. (for example from a navigation controller), the viewDidLayoutSubviews method will know which page to navigate to (for example if the screen was portrait when you left, then you changed to landscape, and navigate back, then viewDidLayoutSubviews will need to change all the sizes of the views, but still know what page to set the offset to)
    currentPageBeforeRotation = [self getCurrentDisplayedPage];
    
    // CHANGE so pageControl is correctly updated
    //update the pagedots pagenuber
    if (pageControl) {
        //set the correct page on the pagedots
        pageControl.currentPage = currentPage;
    }
    
    //call the delegate to tell him you've scrolled to another page
    if([self.delegate respondsToSelector:@selector(didScrollToViewAtIndex:)]){
        [self.delegate didScrollToViewAtIndex:currentPage];
    }
    
    /*Just do a quick check, that if the paging enabled property is YES (paging is enabled), the user should not define widthForPageOnSlidingPagesViewController on the datasource delegate because scrollviews do not cope well with paging being enabled for scrollviews where each subview is not full width! */
    if (self.pagingEnabled == YES && [self.dataSource respondsToSelector:@selector(widthForPageOnSlidingPagesViewController:atIndex:)]){
        NSLog(@"Warning: TTScrollSlidingPagesController. You have paging enabled in the TTScrollSlidingPagesController (pagingEnabled is either not set, or specifically set to YES), but you have also implemented widthForPageOnSlidingPagesViewController:atIndex:. ScrollViews do not cope well with paging being disabled when items have custom widths. You may get weird behaviour with your paging, in which case you should either disable paging (set pagingEnabled to NO) and keep widthForPageOnSlidingPagesViewController:atIndex: implented, or not implement widthForPageOnSlidingPagesViewController:atIndex: in your datasource for the TTScrollSlidingPagesController instance.");
    }
}

#pragma mark UIPageControl page changed listener we set up on it
-(void)pageControlChangedPage:(id)sender
{
    //if not already on the page and the page is within the bounds of the pages we have, scroll to the page!
    int page = pageControl.currentPage;
    if ([self getCurrentDisplayedPage] != page && page < [bottomScrollView.subviews count]){
        [self scrollToPage:page animated:YES];
    }
}

#pragma mark property setters - for when need to do fancy things as well as set the value

-(void)setDataSource:(id<TTSlidingPagesDataSource>)dataSource{
    _dataSource = dataSource;
}

-(void)setPagingEnabled:(BOOL)pagingEnabled{
    _pagingEnabled = pagingEnabled;
    if (bottomScrollView != nil){
        bottomScrollView.pagingEnabled = pagingEnabled;
    }
}

#pragma mark Setters for properties to warn someone if they attempt to set a property after viewDidLoad has already been called (they won't work if so!)
-(void)raiseErrorIfViewDidLoadHasBeenCalled{
    if (viewDidLoadHasBeenCalled)
    {
        [NSException raise:@"TTSlidingPagesController set custom property too late" format:@"The app attempted to set one of the custom properties on TTSlidingPagesController (such as TitleScrollerHeight, TitleScrollerItemWidth etc.) after viewDidLoad has already been loaded. This won't work, you need to set the properties before viewDidLoad has been called - so before you access the .view property or set the dataSource. It is best to set the custom properties immediately after calling init on TTSlidingPagesController"];
    }
}

-(void)setDisableUIPageControl:(BOOL)disableUIPageControl{
    [self raiseErrorIfViewDidLoadHasBeenCalled];
    _disableUIPageControl = disableUIPageControl;
}

// CHANGE - Adding method
- (void)setPageControl:(UIPageControl *)newPageControl {
    pageControl = newPageControl;
}

- (void)triggerScrollViewRecalculation {
    [self.dataSource scrollViewDidScroller:bottomScrollView];
}
@end
