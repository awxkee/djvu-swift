//
//  MADjvuParser.m
//  DjvuViewer
//
//  Created by Alex Martynov on 2/13/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "DjvuParser.h"
#import "ddjvuapi.h"
#import "NSString+UUID.h"
#import <Foundation/Foundation.h>
#import <Accelerate/Accelerate.h>

void convertRGBtoRGBA(char *rgba, const char* rgb, int width, int height) {
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    vImage_Buffer src = {
        .data = (void*)(rgb),
        .width = width,
        .height = height,
        .rowBytes = width * 3
    };

    vImage_Buffer dest = {
        .data = rgba,
        .width = width,
        .height = height,
        .rowBytes = width * 4
    };
    vImage_Error vEerror = vImageConvert_RGB888toRGBA8888(&src, NULL, 255, &dest, true, kvImageNoFlags);
    if (vEerror != kvImageNoError) {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    CGColorSpaceRelease(colorSpace);
}

@interface DjvuParser()

@property(nonatomic, assign) NSUInteger numberOfPages;

@end

@implementation DjvuParser {
    ddjvu_context_t * ctx;
    ddjvu_document_t * document;
}

- (void)dealloc {
    if (document) {
        ddjvu_document_release(document);
    }
    if (ctx) {
        ddjvu_context_release(ctx);
    }
}

- (void)handle:(int)wait
{
    const ddjvu_message_t *msg;
    if (!ctx)
        return;
    if (wait)
        msg = ddjvu_message_wait(ctx);
    while ((msg = ddjvu_message_peek(ctx)))
    {
        switch(msg->m_any.tag)
        {
            case DDJVU_ERROR:
                NSLog(@"ddjvu: %s\n", msg->m_error.message);
                if (msg->m_error.filename)
                    NSLog(@"ddjvu: '%s:%d'\n", msg->m_error.filename, msg->m_error.lineno);
                break;
            default:
                break;
        }
        ddjvu_message_pop(ctx);
    }
}

- (nullable id)initWithPath:(nonnull NSString*)path error:(NSError *_Nullable * _Nullable)error
{
    NSString *uniqueAppID = [NSString stringWithFormat:@"DjvuViewer_%@", [NSString UUID]];
    ctx = ddjvu_context_create([uniqueAppID UTF8String]);
    if (!ctx) {
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Cannot create djvu context" }];
        return NULL;
    }
    document = ddjvu_document_create_by_filename(ctx,
                                                 [path UTF8String],
                                                 FALSE);
    if (!document) {
        ddjvu_context_release(ctx);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Cannot open document" }];
        return NULL;
    }

    while (!ddjvu_document_decoding_done(document))
        [self handle:TRUE];
    if (ddjvu_document_decoding_error(document)) {
        ddjvu_document_release(document);
        ddjvu_context_release(ctx);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Cannot open document" }];
        return NULL;
    }

    int np = ddjvu_document_get_pagenum(document);

    if (np < 0)
        np = 0;

    self.numberOfPages = (NSUInteger)np;
    
    return self;
}

#pragma mark -
#pragma mark properties

@synthesize numberOfPages;

#pragma mark -
#pragma mark public

- (nullable Image*)imageForPage:(NSUInteger)page dpi:(NSUInteger)dpi error:(NSError *_Nullable * _Nullable)error
{
    if (self.numberOfPages == 0) {
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"You're trying to get an image on an invalid document" }];
        return NULL;
    }
    int pageno = (int)page;
    ddjvu_rect_t rect;
    ddjvu_format_t *format;

    ddjvu_page_t * djvu_page = ddjvu_page_create_by_pageno(document, pageno);
    if (djvu_page == NULL)
    {
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Can't create djvu page of number %d", pageno] }];
        return nil;
    }
    while (!ddjvu_page_decoding_done(djvu_page))
        [self handle: TRUE];

    if (ddjvu_page_decoding_error(djvu_page)) {
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Can't decode djvu page of number %d", pageno] }];
        return NULL;
    }

    rect.x = 0;
    rect.y = 0;
    rect.w = ddjvu_page_get_width  (djvu_page) * 100 / dpi;
    rect.h = ddjvu_page_get_height (djvu_page) * 100 / dpi;

    format = ddjvu_format_create (DDJVU_FORMAT_RGB24, 0, 0);
    ddjvu_format_set_row_order(format, 1);

    if (format == NULL)
    {
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Create format for page %d was failed", pageno] }];
        return NULL;
    }

    unsigned long rowsize = rect.w * 3;
    
    unsigned char* rgb = (unsigned char*)malloc(rect.w*rect.h*3);

    int rs = ddjvu_page_render (djvu_page,
                                DDJVU_RENDER_COLOR,
                                &rect,
                                &rect,
                                format,
                                rowsize,
                                (char *)rgb);
    if (!rs) {
        free(rgb);
        ddjvu_format_release(format);
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Render page %d was failed", pageno] }];
        return NULL;
    }

    unsigned char* imgData = NULL;
    imgData = (unsigned char*)malloc(rect.w*rect.h*4); //RGBA

    convertRGBtoRGBA((char*)imgData, (const char*) rgb, rect.w, rect.h);

    free(rgb);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int flags = kCGImageAlphaNoneSkipLast;
    CGContextRef gtx = CGBitmapContextCreate(imgData, rect.w, rect.h, 8, rect.w * 4, colorSpace, flags);
    if (gtx == NULL) {
        ddjvu_format_release(format);
        free(imgData);
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Create CGDataProviderRef has failed" }];
        return NULL;
    }
    CGImageRef imageRef = CGBitmapContextCreateImage(gtx);
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:1 orientation: UIImageOrientationUp];
#endif

    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpace);

    ddjvu_format_release(format);
    ddjvu_page_release(djvu_page);

    free(imgData);

    return image;
}

- (nullable Image*)imageForPage:(NSUInteger)page dpi:(NSUInteger)dpi maxSideSize:(NSUInteger)maxSideSize error:(NSError *_Nullable * _Nullable)error
{
    if (self.numberOfPages == 0) {
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"You're trying to get an image on an invalid document" }];
        return NULL;
    }
    int pageno = (int)page;
    ddjvu_rect_t rect;
    ddjvu_format_t *format;

    ddjvu_page_t * djvu_page = ddjvu_page_create_by_pageno(document, pageno);
    if (djvu_page == NULL)
    {
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Can't create djvu page of number %d", pageno] }];
        return nil;
    }
    while (!ddjvu_page_decoding_done(djvu_page))
        [self handle: TRUE];

    if (ddjvu_page_decoding_error(djvu_page)) {
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Can't decode djvu page of number %d", pageno] }];
        return NULL;
    }

    rect.x = 0;
    rect.y = 0;
    int newWidth = ddjvu_page_get_width  (djvu_page) * 100 / dpi;
    int newHeight = ddjvu_page_get_height (djvu_page) * 100 / dpi;

    float resizeFactor = 1.0f;

    if (newWidth > maxSideSize && newHeight > maxSideSize) {
        if (newWidth > newHeight) {
            newHeight = ((float)maxSideSize/(float)newWidth)*newHeight;
            newWidth = (unsigned int)maxSideSize;
        } else {
            newWidth = ((float)maxSideSize/(float)newHeight)*newWidth;
            newHeight = (unsigned int)maxSideSize;
        }
    }

    rect.w = newWidth;
    rect.h = newHeight;

    format = ddjvu_format_create (DDJVU_FORMAT_RGB24, 0, 0);
    ddjvu_format_set_row_order(format, 1);

    if (format == NULL)
    {
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Create format for page %d was failed", pageno] }];
        return NULL;
    }

    unsigned long rowsize = rect.w * 3;

    unsigned char* rgb = (unsigned char*)malloc(rect.w*rect.h*3);

    int rs = ddjvu_page_render (djvu_page,
                                DDJVU_RENDER_COLOR,
                                &rect,
                                &rect,
                                format,
                                rowsize,
                                (char *)rgb);
    if (!rs) {
        free(rgb);
        ddjvu_format_release(format);
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Render page %d was failed", pageno] }];
        return NULL;
    }

    unsigned char* imgData = NULL;
    imgData = (unsigned char*)malloc(rect.w*rect.h*4); //RGBA

    convertRGBtoRGBA((char*)imgData, (const char*) rgb, rect.w, rect.h);

    free(rgb);

    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    int flags = kCGImageAlphaNoneSkipLast;
    CGContextRef gtx = CGBitmapContextCreate(imgData, rect.w, rect.h, 8, rect.w * 4, colorSpace, flags);
    if (gtx == NULL) {
        ddjvu_format_release(format);
        free(imgData);
        ddjvu_page_release(djvu_page);
        *error = [[NSError alloc] initWithDomain:@"DjvuParser" code:500 userInfo:@{ NSLocalizedDescriptionKey: @"Create CGDataProviderRef has failed" }];
        return NULL;
    }
    CGImageRef imageRef = CGBitmapContextCreateImage(gtx);
    Image *image = nil;
#if TARGET_OS_OSX
    image = [[NSImage alloc] initWithCGImage:imageRef size:CGSizeZero];
#else
    image = [UIImage imageWithCGImage:imageRef scale:1 orientation: UIImageOrientationUp];
#endif

    CGImageRelease(imageRef);
    CGColorSpaceRelease(colorSpace);

    ddjvu_format_release(format);
    ddjvu_page_release(djvu_page);
    free(imgData);

    return image;
}

@end
