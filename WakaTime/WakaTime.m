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

static NSString *VERSION = @"3.0.0";
static NSString *XCODE_VERSION = nil;
static NSString *XCODE_BUILD = nil;
static NSString *WAKATIME_CLI = @".wakatime/wakatime-cli";
static NSString *CONFIG_FILE = @".wakatime.cfg";
static int FREQUENCY = 2; // minutes
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
        [notification_center addObserver:self selector:@selector(handleMouseMoved:) name:@"DVTSourceExpressionUnderMouseDidChangeNotification" object:nil];
        //[notification_center addObserver:self selector:@selector(handleSelectionChanged:) name:@"SourceEditorSelectedSourceRangeChangedNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleSourceDiagnosticsChanged:) name:@"SourceEditorDiagnosticsChangedNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleWindowDidBecomeMain:) name:@"NSWindowDidBecomeMainNotification" object:nil];

        // build event handlers
        [notification_center addObserver:self selector:@selector(handleBuildWillStart:) name:@"IDEBuildOperationWillStartNotification" object:nil];
        [notification_center addObserver:self selector:@selector(handleBuildStopped:) name:@"IDEBuildOperationDidStopNotification" object:nil];

        // for debugging, uncomment following line to write all notification
        // events to stdout, and /tmp/xcode-wakatime-debug.log, if file exists
        // (touch /tmp/xcode-wakatime-debug.log then tail -f /tmp/xcode-wakatime-debug.log)
        // [notification_center addObserver:self selector:@selector(handleNotification:) name:nil object:nil];

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

-(void)handleWindowDidBecomeMain:(NSNotification *)notification {
    if (self.lastFile)
        return;

    IDEWorkspaceWindow *window = (IDEWorkspaceWindow *)[notification object];
    IDEEditorDocument *document = [window document];
    if (!document)
        return;

    NSURL *url = document.fileURL;
    if (!url || !url.path)
        return;

    self.lastFile = [self stripFileProtocol:[NSString stringWithFormat:@"%@/contents.xcworkspacedata", url.path]];
}

-(void)handleSourceDiagnosticsChanged:(NSNotification *)notification {
    if (self.lastFile && ![self.lastFile hasSuffix:@"contents.xcworkspacedata"])
        return;

    IDEEditorDocument *editorDocument = (IDEEditorDocument *)[notification object];
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;

    self.lastFile = [self stripFileProtocol:filePath.pathString];
}

-(void)handleCursorMoved:(NSNotification *)notification {
    IDEEditorDocument *editorDocument = [(IDESourceCodeEditor *)[notification object] sourceCodeDocument];
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;

    NSString *currentFile = [self stripFileProtocol:filePath.pathString];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    if ([self shouldSendHeartbeat:currentFile time:currentTime]) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeatWithWrite:false];
    }
}

-(void)handleMouseMoved:(NSNotification *)notification {
    if (!self.lastFile)
        return;

    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    if ([self shouldSendHeartbeat:self.lastFile time:currentTime]) {
        self.lastTime = currentTime;
        [self sendHeartbeatWithWrite:false];
    }
}

-(void)handleFileChanged:(NSNotification *)notification {
    NSDictionary *dict = notification.object;
    DVTDocumentLocation *next = [dict objectForKey:@"next"];
    if (next == NULL)
        return;

    NSString *currentFile = [self stripFileProtocol:next.documentURLString];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    if ([self shouldSendHeartbeat:currentFile time:currentTime]) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeatWithWrite:false];
    }
}

-(void)handleFileSaved:(NSNotification *)notification {
    IDEEditorDocument *editorDocument = (IDEEditorDocument *)notification.object;
    DVTFilePath *filePath = (DVTFilePath *)editorDocument.filePath;

    NSString *currentFile = [self stripFileProtocol:filePath.pathString];

    if (currentFile) {
        self.lastFile = currentFile;
        self.lastTime = CFAbsoluteTimeGetCurrent();
        [self sendHeartbeatWithWrite:true];
    }
}

-(void)handleBuildWillStart:(NSNotification *)notification {
    self.isBuilding = true;
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();

    [self sendHeartbeatWithWrite:false];

    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:BUILD_CHECK_FREQUENCY];
}

-(void)checkStillBuilding {
    if (!self.isBuilding)
        return;

    NSString *currentFile = [self getLastFileOrProject];
    CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();

    if ([self shouldSendHeartbeat:currentFile time:currentTime]) {
        self.lastFile = currentFile;
        self.lastTime = currentTime;
        [self sendHeartbeatWithWrite:false];
    }

    [self performSelector:@selector(checkStillBuilding) withObject:nil afterDelay:BUILD_CHECK_FREQUENCY];
}

-(void)handleBuildStopped:(NSNotification *)notification {
    self.isBuilding = false;
    self.lastFile = [self getLastFileOrProject];
    self.lastTime = CFAbsoluteTimeGetCurrent();

    [self sendHeartbeatWithWrite:false];
}

-(void)sendHeartbeatWithWrite:(BOOL)write {
    if (!self.lastFile)
        return;

    NSTask *task = [[NSTask alloc] init];
    [task setLaunchPath: [NSHomeDirectory() stringByAppendingPathComponent:WAKATIME_CLI]];

    // Handle Playgrounds
    if ([@"playground" isEqualToString: self.lastFile.pathExtension])
        self.lastFile = [self.lastFile stringByAppendingPathComponent:@"Contents.swift"];

    NSMutableArray *arguments = [NSMutableArray array];
    [arguments addObject:@"--entity"];
    [arguments addObject:self.lastFile];
    [arguments addObject:@"--plugin"];
    [arguments addObject:[NSString stringWithFormat:@"xcode/%@-%@ xcode-wakatime/%@", XCODE_VERSION, XCODE_BUILD, VERSION]];
    if (write)
        [arguments addObject:@"--write"];
    if (self.isBuilding) {
        [arguments addObject:@"--category"];
        [arguments addObject:BUILDING];
    }
    NSString *projectFolder = [self getProjectFolder];
    if (projectFolder) {
        [arguments addObject:@"--project-folder"];
        [arguments addObject:projectFolder];
    }

    [task setArguments: arguments];

    NSError* err;
    [task launchAndReturnError:&err];
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

- (NSString *)getProjectFolder {
    NSArray *workspaceWindowControllers = [NSClassFromString(@"IDEWorkspaceWindowController") valueForKey:@"workspaceWindowControllers"];

    id workSpace;

    for (id controller in workspaceWindowControllers) {
        if ([[controller valueForKey:@"window"] isEqual:[NSApp keyWindow]]) {
            workSpace = [controller valueForKey:@"_workspace"];
        }
    }

    if (workSpace == nil) return nil;

    NSString *workspacePath = [[workSpace valueForKey:@"representingFilePath"] valueForKey:@"_pathString"];
    if (workspacePath) {
        NSArray *components = [workspacePath pathComponents];
        if (components.count > 1)
            return [NSString pathWithComponents: [components subarrayWithRange:(NSRange){ 0, components.count - 1}]];
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

-(BOOL)shouldSendHeartbeat:(NSString *)file time:(CFAbsoluteTime)time {
    int minutes = FREQUENCY * 60;
    return file && (![file isEqualToString:self.lastFile] || self.lastTime + minutes < time);
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
    NSString *className = @"UnknownObject";
    if ([((NSObject*)notification.object) respondsToSelector:@selector(className)]) {
        className = ((NSObject*)notification.object).className;
    }
    NSString *msg = [NSString stringWithFormat:@"Notification.name=%@ (%@)", notification.name, className];
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
