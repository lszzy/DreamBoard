#import "ExposeSwitcher.h"

@implementation ExposeSwitcher

@synthesize scanPath, cachePath, current, backgroundPath, shadowPath, delegate;


static NSString *shadowImagePath;
static UIImage *shadowImage;
static ExposeSwitcher *sharedInstance;

static const double XGAP = 47.5/2;
static const double YGAP = 55./2;
static const int TOPGAP = 40;
static const int BOTGAP = 20;
static const int ROWS = 3;
static const int COLS = 3;
static const int NUM  = 9;

- (id)init
{
    self = [super init];
    if (self) {
        bounds = [[UIScreen mainScreen] bounds];
        
        width = (bounds.size.width-XGAP*(COLS+1))/COLS;
        height = (bounds.size.height-TOPGAP-BOTGAP-YGAP*ROWS)/ROWS;

        switcherObjects = [[NSMutableArray alloc] init];
        sharedInstance = self;
    }
    return self;
}

-(void)updateCache
{
    if(!scanPath || !cachePath)return;
    NSArray *ray = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:scanPath error:NULL];
    if(![[NSFileManager defaultManager] fileExistsAtPath:cachePath])
        [[NSFileManager defaultManager] createDirectoryAtPath:cachePath withIntermediateDirectories:YES attributes:nil error:nil];
    for(int i =0; i<(int)ray.count; i++){
        NSString *path1 = [NSString stringWithFormat:@"%@/%@/Preview.png", scanPath, ray[i]];
        NSString *path2 = [NSString stringWithFormat:@"%@/%@.timestamp", cachePath, ray[i]];
        if(![[NSFileManager defaultManager] fileExistsAtPath:path1])continue;
        if([[NSFileManager defaultManager] fileExistsAtPath:path2]){
            NSString *stamp = [NSString stringWithContentsOfFile:path2 encoding:NSUTF8StringEncoding error:nil];
            NSString *newstamp = [NSString stringWithFormat:@"%f",[(NSDate*)[[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil][@"NSFileModificationDate"] timeIntervalSince1970]];
            if([stamp isEqualToString:newstamp])continue;
        }
        UIImageView *temp = [[UIImageView alloc] initWithFrame:CGRectMake(0,0,width,height)];
        temp.image = [UIImage imageWithContentsOfFile:path1];
        for(int j = 0; j<2; j++){
            UIGraphicsBeginImageContext(CGSizeMake(width*(j==0?1:2),height*(j==0?1:2)));
            CGContextScaleCTM( UIGraphicsGetCurrentContext(), (j==0?1:2), (j==0?1:2) );
            [[temp layer] renderInContext:UIGraphicsGetCurrentContext()];
            UIImage* viewImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();
            [UIImagePNGRepresentation(viewImage) writeToFile:[NSString stringWithFormat:@"%@/%@%@.png", cachePath, ray[i], (j==0?@"":@"@2x")] atomically:YES];
        }
        NSString *newstamp = [NSString stringWithFormat:@"%f",[(NSDate*)[[NSFileManager defaultManager] attributesOfItemAtPath:path1 error:nil][@"NSFileModificationDate"] timeIntervalSince1970]];
        [newstamp writeToFile:path2 atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (void)loadView
{
    [super loadView];
    
    self.view.frame= bounds;
    self.view.userInteractionEnabled = NO;
	NSMutableArray *ray = [[[NSFileManager defaultManager] contentsOfDirectoryAtPath:scanPath error:NULL] mutableCopy];
    
    if([ray containsObject:@"Default"]){
		[ray removeObject:@"Default"];
		[ray insertObject:@"Default" atIndex:0];
	}
    
    int index = 0;
	for(int i = 0; i<(int)ray.count; i++)
		if([[NSFileManager defaultManager] fileExistsAtPath:[NSString stringWithFormat:@"%@/%@/Info.plist", scanPath, ray[i]]]){
            if([ray[i] isEqualToString:current]) index = (int)switcherObjects.count;
            ExposeSwitcherObject *object = [[ExposeSwitcherObject alloc] initWithName:ray[i]];
            [switcherObjects addObject:object];
        }
    
    mainScrollView = [[UIScrollView alloc] initWithFrame:bounds];
    mainScrollView.contentSize = CGSizeMake(bounds.size.width*(((int)switcherObjects.count-1)/NUM+1), bounds.size.height);
    mainScrollView.pagingEnabled = YES;
    mainScrollView.showsHorizontalScrollIndicator = NO;
    mainScrollView.clipsToBounds = YES;
    mainScrollView.opaque = YES;
    mainScrollView.delegate = self;
    
    background = [[UIImageView alloc] initWithFrame:bounds];
    background.image = [UIImage imageWithContentsOfFile:backgroundPath];
    
    shadow = [[UIImageView alloc] initWithFrame:CGRectMake(0,bounds.size.height-bounds.size.height*.375,bounds.size.width, bounds.size.height*.375)];
    shadow.image = [UIImage imageWithContentsOfFile:shadowPath];
    
    previewImage = [[UIImageView alloc] initWithFrame:bounds];
    previewImage.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/Preview.png", scanPath, [switcherObjects[index] name]]];
    previewImage.alpha = 0;
    previewImage.tag = index;
    
    pagectrl = [[UIPageControl alloc] initWithFrame:CGRectMake(0,bounds.size.height-BOTGAP,bounds.size.width, BOTGAP)];
    pagectrl.defersCurrentPageDisplay = YES;
    
    shadow.hidden = YES;
    background.hidden = YES;
    mainScrollView.hidden = YES;
    pagectrl.alpha = 0;
    
    int i = 0;
    while(i<(int)switcherObjects.count)
        for(int r = 0; r<ROWS && i<(int)switcherObjects.count; r++)
            for(int c = 0; c<COLS && i<(int)switcherObjects.count; i++,c++){
                
                x[r][c] = XGAP + c*(XGAP+width);
                y[r][c] = TOPGAP + r*(height+YGAP);
                
                CGRect frame = CGRectMake(x[r][c] + i/NUM*bounds.size.width,
                                          y[r][c], width, height);
                [switcherObjects[i] setFrame:frame];
                [switcherObjects[i] setIndex:i];
                [switcherObjects[i] setRow:r];
                [switcherObjects[i] setCol:c];
                [mainScrollView addSubview:switcherObjects[i]];
            }
    
    ExposeSwitcherObject *theme = switcherObjects[index];
    int r = theme.row;
    int c = theme.col;
    mainScrollView.contentOffset = CGPointMake(index/NUM*bounds.size.width,0);
    
    if( ![[DreamBoard sharedInstance] sbView]){
        [self.view addSubview:background];
        [self.view addSubview:shadow];
    }
    [self.view addSubview:mainScrollView];
    [self.view addSubview:pagectrl];
    
    if( !([theme.name isEqualToString:@"Default"] && [[DreamBoard sharedInstance] sbView] ) )
        [self.view addSubview:previewImage];
    else
        [theme layoutSubviews];
    
    [self updatePages];

    mainScrollView.transform = CGAffineTransformMakeScale(bounds.size.width/width, bounds.size.height/height);
    mainScrollView.layer.anchorPoint = CGPointMake((x[r][c]+width/2)/bounds.size.width,(y[r][c]+height/2)/bounds.size.height);
    animationkey = 0;
    [UIView beginAnimations:nil context:nil];   
    [UIView setAnimationDuration:.3];
    [UIView setAnimationDelegate:self]; 
    [UIView setAnimationDidStopSelector:@selector(animationDidFinish)];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    previewImage.alpha = 1;
    [UIView commitAnimations];
}

-(void)updatePages{
    pagectrl.currentPage = round((float)mainScrollView.contentOffset.x/bounds.size.width);
    pagectrl.numberOfPages = (switcherObjects.count-1)/NUM+1;
}

-(void)scrollViewDidScroll:(UIScrollView *)scrollView{
    [self updatePages];
}

-(void)animationDidFinish{
    if(animationkey==0)
    {
        if ([delegate respondsToSelector:@selector(didFadeOut:)])
            [delegate didFadeOut:self];
        background.hidden = NO;
        shadow.hidden = NO;
        mainScrollView.hidden = NO;
        animationkey = 1;
        [UIView beginAnimations:nil context:nil];   
        [UIView setAnimationDuration:.7];
        [UIView setAnimationDelegate:self];
        [UIView setAnimationDidStopSelector:@selector(animationDidFinish)];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        ExposeSwitcherObject* theme = switcherObjects[previewImage.tag];
        int r = [theme row];
        int c = [theme col];
        previewImage.frame = CGRectMake(x[r][c],y[r][c],width,height);
        mainScrollView.transform = CGAffineTransformMakeScale(1,1);
        mainScrollView.frame = bounds;
        pagectrl.alpha = 1;
        [UIView commitAnimations];
    }
    else if(animationkey==1)
    {
        animationkey = 2;
        [UIView beginAnimations:nil context:nil];   
        [UIView setAnimationDuration:.3];
        [UIView setAnimationDelegate:self]; 
        [UIView setAnimationDidStopSelector:@selector(animationDidFinish)];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        previewImage.alpha = 0;
        [UIView commitAnimations];
    }
    else if(animationkey==2)
    {
        if ([delegate respondsToSelector:@selector(didFinishZoomingOut:)])
            [delegate didFinishZoomingOut:self];
        [previewImage removeFromSuperview];
        self.view.userInteractionEnabled = YES;
    }
    else if(animationkey==3)
    {
        animationkey = 4;
        shadow.hidden = YES;
        background.hidden = YES;
        mainScrollView.hidden = YES;
        if ([delegate respondsToSelector:@selector(didSelectObject:view:)])
            [delegate didSelectObject:[switcherObjects[previewImage.tag] name] view:self];
        [UIView beginAnimations:nil context:nil];
        [UIView setAnimationDuration:.3];
        [UIView setAnimationDelegate:self]; 
        [UIView setAnimationDidStopSelector:@selector(animationDidFinish)];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        previewImage.alpha = 0;
        [UIView commitAnimations];
    }else if(animationkey==4){
        [self.view removeFromSuperview];
        if ([delegate respondsToSelector:@selector(didFinishSelection:)])
            [delegate didFinishSelection:self];
    }
}


-(void)viewDidLoad{
    [super viewDidLoad];
}

-(void)didReceiveMemoryWarning{
    [super didReceiveMemoryWarning];
    [mainScrollView removeFromSuperview];
    [background removeFromSuperview];
    [shadow removeFromSuperview];
    [pagectrl removeFromSuperview];
}

- (void)dealloc
{
    shadowImage = nil;
}

+(UIImage *)shadowImage{
    if(!shadowImage)shadowImage = [[UIImage alloc] initWithContentsOfFile:shadowImagePath];
    return shadowImage;
}
+(void)setShadowImagePath:(NSString*)path{
    shadowImagePath = path;
}

+(ExposeSwitcher*)sharedInstance{
    return sharedInstance;
}

-(void)switchTo:(ExposeSwitcherObject*)theme{
    self.view.userInteractionEnabled = NO;
    animationkey = 3;
    previewImage = [[UIImageView alloc] initWithFrame:CGRectMake(x[theme.row][theme.col],y[theme.row][theme.col],width,height)];
    previewImage.image = [UIImage imageWithContentsOfFile:[NSString stringWithFormat:@"%@/%@/Preview.png", scanPath,[theme name]]];
    previewImage.tag = theme.index;
    previewImage.alpha = 1;
    if( !([theme.name isEqualToString:@"Default"] && [[DreamBoard sharedInstance] sbView] ) )
        [self.view addSubview:previewImage];
    else
        [theme layoutSubviews];
    mainScrollView.layer.anchorPoint = CGPointMake(.5,.5);
    mainScrollView.frame = bounds;
    mainScrollView.transform = CGAffineTransformMakeScale(bounds.size.width/width, bounds.size.height/height);
    mainScrollView.layer.anchorPoint = CGPointMake((x[theme.row][theme.col]+width/2)/bounds.size.width,(y[theme.row][theme.col]+height/2)/bounds.size.height);
    CGRect stretch = mainScrollView.frame;
    mainScrollView.transform = CGAffineTransformMakeScale(1,1);
    mainScrollView.frame = bounds;
    if([delegate respondsToSelector:@selector(aboutToZoomIn:)])
        [delegate aboutToZoomIn:theme];
    [UIView beginAnimations:nil context:nil];   
    [UIView setAnimationDuration:.7];
    [UIView setAnimationDelegate:self]; 
    [UIView setAnimationDidStopSelector:@selector(animationDidFinish)];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    mainScrollView.transform = CGAffineTransformMakeScale(bounds.size.width/width, bounds.size.height/height);
    mainScrollView.frame = stretch;
    pagectrl.alpha=0;
    previewImage.frame = bounds;
    [UIView commitAnimations];
}

-(void)didHold:(ExposeSwitcherObject *)theme{
    if([delegate respondsToSelector:@selector(didHold:)])
        [delegate didHold:theme];
}

@end
