//
//  WakaTime.m
//
//  :description: WakaTime Xcode Plugin
//
//  :maintainer: WakaTime <support@wakatime.com>
//  :license: BSD, see LICENSE for more details.
//  :website: https://wakatime.com/

#import "WakaTime.h"
#import "XcodeClasses.h"

static NSString *VERSION = @"2.0.9";
static NSString *XCODE_VERSION = nil;
static NSString *XCODE_BUILD = nil;
static NSString *WAKATIME_CLI = @"Library/Application Support/Developer/Shared/Xcode/Plug-ins/WakaTime.xcplugin/Contents/Resources/wakatime-master/wakatime/cli.py";
static NSString *CONFIG_FILE = @".wakatime.cfg";
static int FREQUENCY = 2;  // minutes

static WakaTime *sharedPlugin;

@interface WakaTime()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSString *lastFile;
@property (nonatomic) CFAbsoluteTime lastTime;

@end

@implementation WakaTime

+ (void)pluginDidLoad:(NSBundle *)plugin {
    static id sharedPlugin = nil;
    static dispatch_once_t onceToken;
    NSString *currentApplicationName = [[NSBundle mainBundle] infoDictionary][@"CFBundleName"];
    if ([currentApplicationName isEqual:@"Xcode"]) {
        
        // Set runtime constants
        CONFIG_FILE = [NSHomeDirectory() stringByAppendingPathComponent:CONFIG_FILE];
        XCODE_VERSION = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
        XCODE_BUILD = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        
        dispatch_once(&onceToken, ^{
            sharedPlugin = [[self alloc] initWithBundle:plugin];
        });
    }
}

- (id)initWithBundle:(NSBundle *)plugin {
    if (self = [super init]) {
        NSLog(@"Initializing WakaTime plugin v%@ (http://wakatime.com)", VERSION);
        
        // reference to plugin's bundle, for resource access
        self.bundle = plugin;
        
        // Prompt for api_key if not already set
        NSString *api_key = [[self getApiKey] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (api_key == NULL || [api_key length] == 0) {
            [self promptForApiKey];
        }
        
        // setup event handlers
        NSNotificationCenter *notification_center = [NSNotificationCenter defaultCenter];
        [notification_center addObserver:self selector:@selector(handleChangeFile:) name:@"transition from one file to another" object:nil];
        [notification_center addObserver:self selector:@selector(handleSaveFile:) name:@"IDEEditorDocumentDidSaveNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleCursorMove:) name:@"DVTSourceExpressionSelectedExpressionDidChangeNotification" object:nil];
        //[notification_center addObserver:self selector:@selector(handleMouseMove:) name:@"DVTSourceExpressionUnderMouseDidChangeNotification" object:nil];

        // setup File menu item
        [self performSelector:@selector(createMenuItem) withObject:nil afterDelay:3];
    }
    return self;
}

-(void)createMenuItem {
    NSMenuItem *fileMenuItem = [[NSApp mainMenu] itemWithTitle:@"File"];
    if (fileMenuItem) {
        [[fileMenuItem submenu] addItem:[NSMenuItem separatorItem]];
        NSMenuItem *wakatimeMenuItem = [[NSMenuItem alloc] initWithTitle:@"WakaTime API Key"
                                                            action:@selector(promptForApiKey)
                                                            keyEquivalent:@""];
        wakatimeMenuItem.target = self;
        [[fileMenuItem submenu] addItem:wakatimeMenuItem];
    }
}

-(void)handleCursorMove:(NSNotification *)notification {
    
    IDEEditorDocument *editorDocument = [(IDESourceCodeEditor *)[notification object] sourceCodeDocument];
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;
    
    NSString *currentFile = filePath.pathString;
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // check if we should send this action to api
    if (currentFile && (![self.lastFile isEqualToString:currentFile] || self.lastTime + FREQUENCY * 60 < currentTime)) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendAction:false];
    }
}

-(void)handleChangeFile:(NSNotification *)notification {
    
    NSDictionary *dict = notification.object;
    DVTDocumentLocation *next = [dict objectForKey:@"next"];
    if (next == NULL)
        return;
    
    NSString *currentFile = next.documentURLString;
    if ([[currentFile substringToIndex:7] isEqualToString:@"file://"])
        currentFile = [currentFile substringFromIndex:7];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // check if we should send this action to api
    if (currentFile && (![self.lastFile isEqualToString:currentFile] || self.lastTime + FREQUENCY * 60 < currentTime)) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendAction:false];
    }
}

-(void)handleSaveFile:(NSNotification *)notification {
    
    IDEEditorDocument *editorDocument = (IDEEditorDocument *)notification.object;
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;
    
    NSString *currentFile = filePath.pathString;
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    // always send action to api if isWrite is true
    if (currentFile) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendAction:true];
    }
}

-(void)handleMouseMove:(NSNotification *)notification {
    NSLog(@"****** %@: %@", notification.name, notification.object);
}

-(void)sendAction:(BOOL)isWrite {
    if (self.lastFile) {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: @"/usr/bin/python"];
        
        NSMutableArray *arguments = [NSMutableArray array];
        [arguments addObject:[NSHomeDirectory() stringByAppendingPathComponent:WAKATIME_CLI]];
        [arguments addObject:@"--file"];
        [arguments addObject:self.lastFile];
        [arguments addObject:@"--plugin"];
        [arguments addObject:[NSString stringWithFormat:@"xcode/%@-%@ xcode-wakatime/%@", XCODE_VERSION, XCODE_BUILD, VERSION]];
        if (isWrite)
            [arguments addObject:@"--write"];
        [task setArguments: arguments];
        [task launch];
    }
}

// Read api key from config file
- (NSString *)getApiKey {
    NSString *contents = [NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];[NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [contents componentsSeparatedByString:@"\n"];
    for (NSString *s in lines) {
        NSArray *line = [s componentsSeparatedByString:@"="];
        if ([line count] == 2) {
            NSString *key = [[line objectAtIndex:0] stringByReplacingOccurrencesOfString:@" " withString:@""];
            if ([key isEqualToString:@"api_key"]) {
                NSString *value = [[line objectAtIndex:1] stringByReplacingOccurrencesOfString:@" " withString:@""];
                return value;
            }
        }
    }
    return NULL;
}

// Write api key to config file
- (void)saveApiKey:(NSString *)api_key {
    NSString *contents = [NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];[NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [contents componentsSeparatedByString:@"\n"];
    NSMutableArray *new_contents = [NSMutableArray array];
    BOOL found = false;
    for (NSString *s in lines) {
        NSArray *line = [[s stringByReplacingOccurrencesOfString:@" = " withString:@"="] componentsSeparatedByString:@"="];
        if ([line count] == 2) {
            NSString *key = [line objectAtIndex:0];
            if ([key isEqualToString:@"api_key"]) {
                found = true;
                line = @[@"api_key", api_key];
            }
        }
        [new_contents addObject:[line componentsJoinedByString:@" = "]];
    }
    if ([new_contents count] == 0 || !found) {
        [new_contents removeAllObjects];
        [new_contents addObject:@"[settings]"];
        [new_contents addObject:[NSString stringWithFormat:@"api_key = %@", api_key]];
    }
    NSError *error = nil;
    NSString *to_write = [new_contents componentsJoinedByString:@"\n"];
    [to_write writeToFile:CONFIG_FILE atomically:YES encoding:NSASCIIStringEncoding error:&error];
    if (error) {
        NSLog(@"Fail: %@", [error localizedDescription]);
    }
}

// Prompt for api key
- (void)promptForApiKey {
    NSString *api_key = [self getApiKey];
    NSAlert *alert = [NSAlert alertWithMessageText:@"Enter your api key from wakatime.com" defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:@""];
    NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 300, 24)];
    if (api_key != NULL) {
        [input setStringValue:api_key];
    }
    [alert setAccessoryView:input];
    [alert runModal];
    api_key = [input stringValue];
    [self saveApiKey:api_key];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
