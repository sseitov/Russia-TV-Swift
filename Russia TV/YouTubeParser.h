//
//  YouTubeParser.h
//  Russia TV
//
//  Created by Сергей Сейтов on 02.04.17.
//  Copyright © 2017 V-Channel. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <HCYoutubeParser.h>

@interface YouTubeParser : HCYoutubeParser

+ (void)videoWithYoutubeURL:(NSURL *)youtubeURL
              completeBlock:(void(^)(NSString *videoURL, NSError *error))completeBlock;

@end
