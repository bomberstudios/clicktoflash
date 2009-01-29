/*

The MIT License

Copyright (c) 2008 Click to Flash Developers

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

*/


#import "Plugin.h"
#import "CTFWhitelistWindowController.h"

static NSString *sFlashOldMIMEType = @"application/x-shockwave-flash";
static NSString *sFlashNewMIMEType = @"application/futuresplash";
static NSString *sHostWhitelistDefaultsKey = @"ClickToFlash.whitelist";

@interface CTFClickToFlashPlugin (Internal)
- (void) _convertTypesForContainer;
- (void) _drawBackground;
- (BOOL) _isOptionPressed;
- (BOOL) _isHostWhitelisted;
- (NSMutableArray *)_hostWhitelist;
- (void) _addHostToWhitelist;
- (void) _removeHostFromWhitelist;
@end


@implementation CTFClickToFlashPlugin


#pragma mark -
#pragma mark Class Methods

+ (NSView *)plugInViewWithArguments:(NSDictionary *)arguments
{
    return [[[self alloc] initWithArguments:arguments] autorelease];
}


#pragma mark -
#pragma mark Initialization and Superclass Overrides

- (id) initWithArguments:(NSDictionary *)arguments
{
    self = [super init];
    if (self) {
        self.container = [arguments objectForKey:WebPlugInContainingElementKey];
    
        NSURL *base = [arguments objectForKey:WebPlugInBaseURLKey];
        if (base) {
            self.host = [base host];
            if ([self _isHostWhitelisted] && ![self _isOptionPressed]) {
                [self performSelector:@selector(_convertTypesForContainer) withObject:nil afterDelay:0];
            }
        }

        if (![NSBundle loadNibNamed:@"ContextualMenu" owner:self])
            NSLog(@"Could not load conextual menu plugin");

        NSDictionary *attributes = [arguments objectForKey:WebPlugInAttributesKey];
        if (attributes != nil) {
            NSString *src = [attributes objectForKey:@"src"];
            if (src)
                [self setToolTip:src];
            else {
                src = [attributes objectForKey:@"data"];
                if (src)
                    [self setToolTip:src];
            }
        }
    }

    return self;
}


- (void) dealloc
{
    self.container = nil;
    self.host = nil;
    [_whitelistWindowController release];
    [super dealloc];
}


- (void) drawRect:(NSRect)rect
{
    [self _drawBackground];
}


- (void) mouseDown:(NSEvent *)event
{
    [self _convertTypesForContainer];
}

- (NSMenu *)menuForEvent:(NSEvent *)theEvent
{
    return [self menu];
}

- (BOOL) _isOptionPressed;
{
    BOOL isOptionPressed = (([[NSApp currentEvent] modifierFlags] & NSAlternateKeyMask) != 0);
    return isOptionPressed;
}

- (BOOL) _isHostWhitelisted
{
    NSArray *hostWhitelist = [[NSUserDefaults standardUserDefaults] stringArrayForKey:sHostWhitelistDefaultsKey];
    return hostWhitelist && [hostWhitelist containsObject:self.host];
}

- (NSMutableArray *)_hostWhitelist
{
    NSMutableArray *hostWhitelist = [[[[NSUserDefaults standardUserDefaults] stringArrayForKey:sHostWhitelistDefaultsKey] mutableCopy] autorelease];
    if (hostWhitelist == nil) {
        hostWhitelist = [NSMutableArray array];
    }
    return hostWhitelist;
}

- (void) _addHostToWhitelist
{
    NSMutableArray *hostWhitelist = [self _hostWhitelist];
    [hostWhitelist addObject:self.host];
    [[NSUserDefaults standardUserDefaults] setObject:hostWhitelist forKey:sHostWhitelistDefaultsKey];
}

- (void) _removeHostFromWhitelist
{
    NSMutableArray *hostWhitelist = [self _hostWhitelist];
    [hostWhitelist removeObject:self.host];
    [[NSUserDefaults standardUserDefaults] setObject:hostWhitelist forKey:sHostWhitelistDefaultsKey];
}

#pragma mark -
#pragma mark Contextual menu

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
    BOOL enabled = YES;
    SEL action = [menuItem action];
    if (action == @selector(addToWhitelist:))
    {
        if ([self _isHostWhitelisted])
            enabled = NO;
    }
    else if (action == @selector(removeFromWhitelist:))
    {
        if (![self _isHostWhitelisted])
            enabled = NO;
    }
    
    return enabled;
}

- (IBAction)addToWhitelist:(id)sender;
{
    if ([self _isHostWhitelisted])
        return;
    
    if ([self _isOptionPressed])
    {
        [self _addHostToWhitelist];
        [self _convertTypesForContainer];
        return;
    }
    
    NSString *title = NSLocalizedString(@"Always load flash for this site?", @"Always load flash for this site?");
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Add %@ to the white list?", @"Add %@ to the white list?"), self.host];

    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:NSLocalizedString(@"Add to white list", @"Add to white list")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(addToWhitelistAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (void)addToWhitelistAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self _addHostToWhitelist];
        [self _convertTypesForContainer];
    }
}

- (IBAction)removeFromWhitelist:(id)sender;
{
    if (![self _isHostWhitelisted])
        return;
    
    NSString *title = NSLocalizedString(@"Remove from white list?", @"Remove from white list?");
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Remove %@ from the white list?", @"Remove %@ from the white list?"), self.host];
    
    NSAlert *alert = [[[NSAlert alloc] init] autorelease];
    [alert addButtonWithTitle:NSLocalizedString(@"Remove from white list", @"Remove from white list")];
    [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
    [alert setMessageText:title];
    [alert setInformativeText:message];
    [alert setAlertStyle:NSInformationalAlertStyle];
    [alert beginSheetModalForWindow:[self window]
                      modalDelegate:self
                     didEndSelector:@selector(removeFromWhitelistAlertDidEnd:returnCode:contextInfo:)
                        contextInfo:nil];
}

- (void)removeFromWhitelistAlertDidEnd:(NSAlert *)alert returnCode:(int)returnCode contextInfo:(void *)contextInfo
{
    if (returnCode == NSAlertFirstButtonReturn)
    {
        [self _removeHostFromWhitelist];
    }
}

- (IBAction)editWhitelist:(id)sender;
{
    if (_whitelistWindowController == nil)
    {
        _whitelistWindowController = [[CTFWhitelistWindowController alloc] init];
    }
    [_whitelistWindowController showWindow:self];
}

- (IBAction)loadFlash:(id)sender;
{
    [self _convertTypesForContainer];
}

#pragma mark -
#pragma mark Drawing

- (void) _drawBackground
{
    NSRect selfBounds  = [self bounds];

    NSRect fillRect   = NSInsetRect(selfBounds, 1.0, 1.0);
    NSRect strokeRect = selfBounds;

    NSColor *startingColor = [NSColor colorWithDeviceWhite:1.0 alpha:0.15];
    NSColor *endingColor = [NSColor colorWithDeviceWhite:0.0 alpha:0.15];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:startingColor endingColor:endingColor];
    
    // Draw fill
    [gradient drawInBezierPath:[NSBezierPath bezierPathWithRect:fillRect] angle:270.0];

    // Draw stroke
    [[NSColor colorWithCalibratedWhite:0.0 alpha:0.50] set];
    [NSBezierPath setDefaultLineWidth:2.0];
    [NSBezierPath setDefaultLineCapStyle:NSSquareLineCapStyle];
    [[NSBezierPath bezierPathWithRect:strokeRect] stroke];

    // Draw an image on top to make it insanely obvious that this is clickable Flash.
    NSString *containerImageName = [[NSBundle bundleForClass:[self class]] pathForResource:@"ContainerImage" ofType:@"png"];  
    NSImage *containerImage = [[NSImage alloc] initWithContentsOfFile:containerImageName];

    NSSize viewSize  = fillRect.size;
    NSSize imageSize = containerImage.size;    

    NSPoint viewCenter;
    viewCenter.x = viewSize.width  * 0.50;
    viewCenter.y = viewSize.height * 0.50;
    
    NSPoint imageOrigin = viewCenter;
    imageOrigin.x -= imageSize.width  * 0.50;
    imageOrigin.y -= imageSize.height * 0.50;
    
    NSRect destinationRect;
    destinationRect.origin = imageOrigin;
    destinationRect.size = imageSize;
    
    // Draw the image centered in the view
    [containerImage drawInRect:destinationRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
  
    [gradient release];
    [containerImage release];
}


#pragma mark -
#pragma mark DOM Conversion

- (void) _convertTypesForElement:(DOMElement *)element
{
    NSString *type = [element getAttribute:@"type"];

    if ([type isEqualToString:sFlashOldMIMEType]) {
        [element setAttribute:@"type" value:sFlashNewMIMEType];
    }
}


- (void) _convertTypesForContainer
{
    DOMElement *newElement = (DOMElement *)[self.container cloneNode:YES];

    DOMNodeList *nodeList = nil;
    NSUInteger i;

    [self _convertTypesForElement:newElement];

    nodeList = [newElement getElementsByTagName:@"object"];
    for (i = 0; i < nodeList.length; i++) {
        [self _convertTypesForElement:(DOMElement *)[nodeList item:i]];
    }

    nodeList = [newElement getElementsByTagName:@"embed"];
    for (i = 0; i < nodeList.length; i++) {
        [self _convertTypesForElement:(DOMElement *)[nodeList item:i]];
    }

    // Just to be safe, since we are about to replace our containing element
    [[self retain] autorelease];
    
    [self.container.parentNode replaceChild:newElement oldChild:self.container];
    self.container = nil;
}


@synthesize container = _container;
@synthesize host = _host;

@end
