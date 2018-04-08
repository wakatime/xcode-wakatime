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

static NSString *CODING = @"coding";
static NSString *BUILDING = @"building";

static WakaTime *sharedPlugin;

@interface WakaTime()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSString *lastFile;
@property (nonatomic, strong) NSString *lastCategory;
@property (nonatomic) CFAbsoluteTime lastTime;
@property (nonatomic) BOOL isBuilding;

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
        
        self.lastFile = nil;
        self.lastCategory = nil;
        self.lastTime = 0;

        // Prompt for api_key if not already set
        NSString *api_key = [[self getApiKey] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (api_key == NULL || [api_key length] == 0) {
            [self promptForApiKey];
        }
        
        NSNotificationCenter *notification_center = [NSNotificationCenter defaultCenter];

        // file event handlers
        [notification_center addObserver:self selector:@selector(handleChangeFile:) name:@"transition from one file to another" object:nil];
        [notification_center addObserver:self selector:@selector(handleSaveFile:) name:@"IDEEditorDocumentDidSaveNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleCursorMove:) name:@"DVTSourceExpressionSelectedExpressionDidChangeNotification" object:nil];
        
        // build event handlers
        [notification_center addObserver:self selector:@selector(handleBuildWillStart:) name:@"IDEBuildOperationWillStartNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleBuildStopped:) name:@"IDEBuildOperationDidStopNotification" object:nil];
        
        // write all notification events to /tmp/xcode-wakatime-debug, if file exists
        //[notification_center addObserver:self selector:@selector(handleNotification:) name:nil object:nil];
        
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

    NSString *currentFile = [self stripFileProtocol:filePath.pathString];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    // check if we should send this action to api
    if (currentFile && (![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime)) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeat:false];
    }
}

-(void)handleChangeFile:(NSNotification *)notification {
    NSDictionary *dict = notification.object;
    DVTDocumentLocation *next = [dict objectForKey:@"next"];
    if (next == NULL)
        return;

    NSString *currentFile = [self stripFileProtocol:next.documentURLString];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    NSString *currentCategory = CODING;

    // check if we should send this action to api
    if (currentFile && (![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime || ![currentCategory isEqual: self.lastCategory])) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        self.lastCategory = BUILDING;
        [self sendHeartbeat:false];
    }
}

-(void)handleSaveFile:(NSNotification *)notification {
    IDEEditorDocument *editorDocument = (IDEEditorDocument *)notification.object;
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;
    NSString *currentFile = [self stripFileProtocol:filePath.pathString];
    if (currentFile) {
        self.lastFile = currentFile;
        self.lastTime = CFAbsoluteTimeGetCurrent();
        [self sendHeartbeat:true];
    }
}

-(void)handleBuildWillStart:(NSNotification *)notification {
    [self debug:@"handleBuildWillStart"];
    self.isBuilding = true;
    self.lastCategory = BUILDING;
    
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();
    [self sendHeartbeat:false];
    
    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:10];
}

-(void)checkStillBuilding {
    [self debug:@"checkStillBuilding"];
    if (!self.isBuilding) {
        [self debug:@"!self.isBuilding"];
        return;
    }
    
    BOOL categoryChanged = ![BUILDING isEqualToString:self.lastCategory];
    [self debug:@"categoryChanged:"];
    [self debug:categoryChanged ? @"YES" : @"NO"];
    self.lastCategory = BUILDING;
    
    NSString *currentFile = [self getLastFileOrProject];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    if (!currentFile || ![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime || categoryChanged) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeat:false];
    }
    
    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:10];
}

-(void)handleBuildStopped:(NSNotification *)notification {
    [self debug:@"handleBuildStopped"];
    self.isBuilding = false;
    self.lastCategory = CODING;
    
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();
    [self sendHeartbeat:false];
}

-(void)handleNotification:(NSNotification *)notification {
    NSString *msg = [NSString stringWithFormat:@"Notification.name=%@ (%@)", notification.name, ((NSObject*)notification.object).className];
    [self debug:msg];
}

-(void)sendHeartbeat:(BOOL)isWrite {
    BOOL isCodingCategory = !self.lastCategory || [CODING isEqualToString:self.lastCategory];
    
    if (self.lastFile) {
        NSTask *task = [[NSTask alloc] init];
        [task setLaunchPath: @"/usr/bin/python"];

        NSMutableArray *arguments = [NSMutableArray array];
        [arguments addObject:[NSHomeDirectory() stringByAppendingPathComponent:WAKATIME_CLI]];

        NSString* file = self.lastFile;
        // Handle Playgrounds
        if ([@"playground" isEqualToString: file.pathExtension])
            file = [file stringByAppendingPathComponent:@"Contents.swift"];

        [arguments addObject:@"--file"];
        [arguments addObject:file];
        [arguments addObject:@"--plugin"];
        [arguments addObject:[NSString stringWithFormat:@"xcode/%@-%@ xcode-wakatime/%@", XCODE_VERSION, XCODE_BUILD, VERSION]];
        if (isWrite)
            [arguments addObject:@"--write"];
        if (isCodingCategory) {
            [arguments addObject:@"--category"];
            [arguments addObject:self.lastCategory];
        }

        [task setArguments: arguments];
        [task launch];
    } else if (!isCodingCategory) {
        // must be indexing
        [self debug:@"indexing"];
    }
}

- (NSString *)getLastFileOrProject {
    if (self.lastFile)
        return self.lastFile;
    
    IDEWorkspaceDocument *workspaceDocument = (IDEWorkspaceDocument *)NSDocumentController.sharedDocumentController.currentDocument;
    if (!workspaceDocument)
        return nil;
    NSURL *url = workspaceDocument.fileURL;
    if (!url || !url.path)
        return nil;
    return [self stripFileProtocol:[NSString stringWithFormat:@"%@/contents.xcworkspacedata", url.path]];
}

// Read api key from config file
- (NSString *)getApiKey {
    NSString *contents = [NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];[NSString stringWithContentsOfFile:CONFIG_FILE encoding:NSUTF8StringEncoding error:nil];
    NSArray *lines = [contents componentsSeparatedByString:@"\n"];
    for (NSString *s in lines) {
        NSArray *line = [s componentsSeparatedByString:@"="];
        if ([line count] == 2) {
            NSString *key = [[line objectAtIndex:0] stringByReplacingOccurrencesOfString:@" " withString:@""];
            if ([@"api_key" isEqualToString:key]) {
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
            if ([@"api_key" isEqualToString:key]) {
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
    if (api_key != NULL)
        [input setStringValue:api_key];
    [alert setAccessoryView:input];
    [alert runModal];
    api_key = [input stringValue];
    [self saveApiKey:api_key];
}

-(NSString *)stripFileProtocol:(NSString *)path {
    if (!path)
        return nil;
    if ([[path substringToIndex:7] isEqualToString:@"file://"])
        return [path substringFromIndex:7];
    return path;
}

-(void)debug:(NSString *)msg {
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    NSLocale *enUSPOSIXLocale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    [dateFormatter setLocale:enUSPOSIXLocale];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSDate *now = [NSDate date];
    NSString *dateString = [dateFormatter stringFromDate:now];
    NSLog(@"%@ %@", dateString, msg);
    NSString *path = @"/tmp/xcode-wakatime-debug.log";
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForWritingAtPath:path];
    [fileHandle seekToEndOfFile];
    NSString *output = [NSString stringWithFormat:@"%@ %@\n", dateString, msg];
    [fileHandle writeData:[output dataUsingEncoding:NSUTF8StringEncoding]];
    [fileHandle closeFile];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
