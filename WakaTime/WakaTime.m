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
static int FREQUENCY = 2; // minutes
static NSString *CODING = @"coding";
static NSString *BUILDING = @"building";
static int BUILD_CHECK_FREQUENCY = 10; // seconds

static WakaTime *sharedPlugin;

@interface WakaTime()

@property (nonatomic, strong) NSBundle *bundle;
@property (nonatomic, strong) NSString *lastFile;
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
        self.lastTime = 0;

        // Prompt for api_key if not already set
        NSString *api_key = [[self getApiKey] stringByReplacingOccurrencesOfString:@" " withString:@""];
        if (api_key == NULL || [api_key length] == 0) {
            [self promptForApiKey];
        }
        
        NSNotificationCenter *notification_center = [NSNotificationCenter defaultCenter];

        // file event handlers
        [notification_center addObserver:self selector:@selector(handleFileChanged:) name:@"transition from one file to another" object:nil];
        [notification_center addObserver:self selector:@selector(handleFileSaved:) name:@"IDEEditorDocumentDidSaveNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleCursorMoved:) name:@"DVTSourceExpressionSelectedExpressionDidChangeNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleSourceDiagnosticsChanged:) name:@"SourceEditorDiagnosticsChangedNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleWindowDidBecomeMain:) name:@"NSWindowDidBecomeMainNotification" object:nil];
        //[notification_center addObserver:self selector:@selector(handleSelectionChanged:) name:@"SourceEditorSelectedSourceRangeChangedNotification" object:nil];
        
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

-(void)handleSourceDiagnosticsChanged:(NSNotification *)notification {
    // only needed to set file while Xcode launching
    if (self.lastFile)
        return;
    
    IDEEditorDocument *editorDocument = (IDEEditorDocument *)[notification object];
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

-(void)handleWindowDidBecomeMain:(NSNotification *)notification {
    // only needed to set file while Xcode launching
    if (self.lastFile)
        return;
    
    IDEWorkspaceWindow *window = (IDEWorkspaceWindow *)[notification object];
    IDEEditorDocument *document = [window document];
    if (!document)
        return;
    
    NSURL *url = document.fileURL;
    if (url && url.path) {
        NSString *currentFile = [self stripFileProtocol:[NSString stringWithFormat:@"%@/contents.xcworkspacedata", url.path]];
        CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
        
        // check if we should send this action to api
        if (currentFile && (![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime)) {
            self.lastFile = currentFile;
            self.lastTime = currentTime;
            [self sendHeartbeat:false];
        }
    }
}

-(void)handleCursorMoved:(NSNotification *)notification {
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

-(void)handleFileChanged:(NSNotification *)notification {
    NSDictionary *dict = notification.object;
    DVTDocumentLocation *next = [dict objectForKey:@"next"];
    if (next == NULL)
        return;

    NSString *currentFile = [self stripFileProtocol:next.documentURLString];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    // check if we should send this action to api
    if (currentFile && (![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime)) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeat:false];
    }
}

-(void)handleFileSaved:(NSNotification *)notification {
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
    self.isBuilding = true;
    
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();
    [self sendHeartbeat:false];
    
    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:BUILD_CHECK_FREQUENCY];
}

-(void)checkStillBuilding {
    if (!self.isBuilding)
        return;
    
    NSString *currentFile = [self getLastFileOrProject];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
    
    if (!currentFile || ![currentFile isEqualToString:self.lastFile] || self.lastTime + FREQUENCY * 60 < currentTime) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeat:false];
    }
    
    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:BUILD_CHECK_FREQUENCY];
}

-(void)handleBuildStopped:(NSNotification *)notification {
    self.isBuilding = false;
    
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();
    [self sendHeartbeat:false];
}

-(void)sendHeartbeat:(BOOL)isWrite {
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
        if (self.isBuilding) {
            [arguments addObject:@"--category"];
            [arguments addObject:BUILDING];
        }

        [task setArguments: arguments];
        [task launch];
    }
}

- (NSString *)getLastFileOrProject {
    if (self.lastFile)
        return self.lastFile;
    
    IDEWorkspaceDocument *workspaceDocument = (IDEWorkspaceDocument *)NSDocumentController.sharedDocumentController.currentDocument;
    if (workspaceDocument) {
        NSURL *url = workspaceDocument.fileURL;
        if (url && url.path)
            return [self stripFileProtocol:[NSString stringWithFormat:@"%@/contents.xcworkspacedata", url.path]];
    }
    
    return nil;
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

-(void)handleNotification:(NSNotification *)notification {
    if ([notification.name  isEqual: @"NSWindowDidUpdateNotification"] || [notification.name  isEqual: @"NSApplicationWillUpdateNotification"]  || [notification.name  isEqual: @"NSApplicationDidUpdateNotification"])
        return;
    NSString *msg = [NSString stringWithFormat:@"Notification.name=%@ (%@)", notification.name, ((NSObject*)notification.object).className];
    [self debug:msg];
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
