//
//  YouTubeParser.m
//  Russia TV
//
//  Created by Сергей Сейтов on 02.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import "YouTubeParser.h"

#define kYoutubeInfoURL      @"https://www.youtube.com/get_video_info?video_id="
#define kYoutubeThumbnailURL @"https://img.youtube.com/vi/%@/%@.jpg"
#define kYoutubeDataURL      @"https://gdata.youtube.com/feeds/api/videos/%@?alt=json"
#define kUserAgent @"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_8_2) AppleWebKit/537.4 (KHTML, like Gecko) Chrome/22.0.1229.79 Safari/537.4"

@interface NSString (QueryString)

/**
 Parses a query string
 
 @return key value dictionary with each parameter as an array
 */
- (NSMutableDictionary *)dictionaryFromQueryStringComponents;


/**
 Convenient method for decoding a html encoded string
 */
- (NSString *)stringByDecodingURLFormat;

@end

@interface NSURL (QueryString)

/**
 Parses a query string of an NSURL
 
 @return key value dictionary with each parameter as an array
 */
- (NSMutableDictionary *)dictionaryForQueryString;

@end

@implementation NSString (QueryString)

- (NSString *)stringByDecodingURLFormat {
    NSString *result = [self stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    result = [result stringByRemovingPercentEncoding];
    return result;
}

- (NSMutableDictionary *)dictionaryFromQueryStringComponents {
    
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    
    for (NSString *keyValue in [self componentsSeparatedByString:@"&"]) {
        NSArray *keyValueArray = [keyValue componentsSeparatedByString:@"="];
        if ([keyValueArray count] < 2) {
            continue;
        }
        
        NSString *key = [[keyValueArray objectAtIndex:0] stringByDecodingURLFormat];
        NSString *value = [[keyValueArray objectAtIndex:1] stringByDecodingURLFormat];
        
        NSMutableArray *results = [parameters objectForKey:key];
        
        if(!results) {
            results = [NSMutableArray arrayWithCapacity:1];
            [parameters setObject:results forKey:key];
        }
        
        [results addObject:value];
    }
    
    return parameters;
}

@end

@implementation NSURL (QueryString)

- (NSMutableDictionary *)dictionaryForQueryString {
    return [[self query] dictionaryFromQueryStringComponents];
}

@end

@implementation YouTubeParser

+ (void)videoWithYoutubeURL:(NSURL *)youtubeURL
                   completeBlock:(void(^)(NSString *videoURL, NSError *error))completeBlock {
    NSString *youtubeID = [self youtubeIDFromYoutubeURL:youtubeURL];
    if (youtubeID) {
        dispatch_queue_t queue = dispatch_queue_create("me.hiddencode.yt.backgroundqueue", 0);
        dispatch_async(queue, ^{
            NSDictionary *dict = [[self class] videosWithYoutubeID:youtubeID];
            dispatch_async(dispatch_get_main_queue(), ^{
                NSString* media = [dict objectForKey:@"medium"];
                completeBlock(media, nil);
            });
        });
    }
    else {
        completeBlock(nil, [NSError errorWithDomain:@"me.hiddencode.yt-parser" code:1001 userInfo:@{ NSLocalizedDescriptionKey: @"Invalid YouTube URL" }]);
    }
}

+ (NSDictionary *)videosWithYoutubeID:(NSString *)youtubeID {
    if (youtubeID) {
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@", kYoutubeInfoURL, youtubeID]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
        [request setValue:kUserAgent forHTTPHeaderField:@"User-Agent"];
        [request setHTTPMethod:@"GET"];
        
        __block NSDictionary *data = nil;
        
        // Lock threads with semaphore
        dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);
        [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData * _Nullable responseData, NSURLResponse * _Nullable response, NSError * _Nullable error) {
            
            if (!error) {
                NSString *responseString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
                
                NSMutableDictionary *parts = [responseString dictionaryFromQueryStringComponents];
                
                if (parts) {
                    NSString *fmtStreamMapString = [[parts objectForKey:@"url_encoded_fmt_stream_map"] objectAtIndex:0];
                    if (fmtStreamMapString.length > 0) {
                        
                        NSArray *fmtStreamMapArray = [fmtStreamMapString componentsSeparatedByString:@","];
                        NSMutableDictionary *videoDictionary = [NSMutableDictionary dictionary];
                        
                        for (NSString *videoEncodedString in fmtStreamMapArray) {
                            NSMutableDictionary *videoComponents = [videoEncodedString dictionaryFromQueryStringComponents];
                            NSString *type = [[[videoComponents objectForKey:@"type"] objectAtIndex:0] stringByDecodingURLFormat];
                            NSString *signature = nil;
                            
                            if (![videoComponents objectForKey:@"stereo3d"]) {
                                if ([videoComponents objectForKey:@"itag"]) {
                                    signature = [[videoComponents objectForKey:@"itag"] objectAtIndex:0];
                                }
                                
                                if (signature && [type rangeOfString:@"mp4"].length > 0) {
                                    NSString *url = [[[videoComponents objectForKey:@"url"] objectAtIndex:0] stringByDecodingURLFormat];
                                    url = [NSString stringWithFormat:@"%@&signature=%@", url, signature];
                                    
                                    NSString *quality = [[[videoComponents objectForKey:@"quality"] objectAtIndex:0] stringByDecodingURLFormat];
                                    if ([videoComponents objectForKey:@"stereo3d"] && [[videoComponents objectForKey:@"stereo3d"] boolValue]) {
                                        quality = [quality stringByAppendingString:@"-stereo3d"];
                                    }
                                    if([videoDictionary valueForKey:quality] == nil) {
                                        [videoDictionary setObject:url forKey:quality];
                                    }
                                }
                            }
                        }
                        
                        data = videoDictionary;
                    }
                    // Check for live data
                    else if ([parts objectForKey:@"live_playback"] != nil && [parts objectForKey:@"hlsvp"] != nil && [[parts objectForKey:@"hlsvp"] count] > 0) {
                        data = @{ @"live": [parts objectForKey:@"hlsvp"][0] };
                    }
                }
            }
            dispatch_semaphore_signal(semaphore);
        }] resume];
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER);
        
        return data;
    }
    return nil;
}

@end
