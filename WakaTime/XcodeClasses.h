//
//  XcodeClasses.h
//
//  :description: Undocumented classes which are implemented by Xcode
//
//  :maintainer: WakaTime <support@wakatime.com>
//  :license: BSD, see LICENSE for more details.
//  :website: https://www.wakatime.com

#import <Foundation/Foundation.h>


@class DVTFilePath;

@interface DVTFilePath : NSObject

@property (retain) NSString *pathString;

@end


@class IDEEditorDocument;

@interface IDEEditorDocument : NSDocument

@property (retain) DVTFilePath *filePath;

@end


@interface DVTDocumentLocation : NSObject

@property(readonly) NSString *documentURLString;

@end


@class IDESourceCodeEditor;

@interface IDESourceCodeEditor : NSObject

@property (retain) IDEEditorDocument *sourceCodeDocument;

@end
