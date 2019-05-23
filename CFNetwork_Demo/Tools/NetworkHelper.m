//
//  NetworkHelper.m
//  CFNetwork_Demo
//
//  Created by 李一贤 on 2019/5/14.
//  Copyright © 2019 atomlee. All rights reserved.
//

#import "NetworkHelper.h"
#import <AdSupport/AdSupport.h>
#import <CommonCrypto/CommonDigest.h>
#define BaseURL "http://duobaosdk-3.com"
#define signKey @"PS"
#define signValue @"d58ca1a03feab0b41dff5140358357ff"

@interface  NetworkHelper()

@property(strong,nonatomic) NSDictionary *postData;

@end

@implementation NetworkHelper


+ (instancetype)shareInstance {
    static NetworkHelper *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NetworkHelper alloc] init];
    });
    return instance;
}

-(void)postUrl{
    //创建请求
    CFStringRef url = CFSTR(BaseURL);
    CFURLRef myURL = CFURLCreateWithString(kCFAllocatorDefault, url, NULL);
    
    CFStringRef requestMethod = CFSTR("POST");
    CFHTTPMessageRef myRequest =
    CFHTTPMessageCreateRequest(kCFAllocatorDefault, requestMethod, myURL,
                               kCFHTTPVersion1_1);
    // 设置body
    NSData *dataToPost = [[self processParams] dataUsingEncoding:NSUTF8StringEncoding];
    CFHTTPMessageSetBody(myRequest, (__bridge CFDataRef) dataToPost);
    // 设置header
    CFHTTPMessageSetHeaderFieldValue(myRequest, CFSTR("Content-Type"), CFSTR("application/x-www-form-urlencoded; charset=utf-8"));
    
    //创建流并开启
    CFReadStreamRef requestStream = CFReadStreamCreateForHTTPRequest(NULL, myRequest);
    CFReadStreamOpen(requestStream);
    //接收响应
    NSMutableData *responseBytes = [NSMutableData data];
    CFIndex numBytesRead = 0;
    do {
        UInt8 buf[1024];
        numBytesRead = CFReadStreamRead(requestStream, buf, sizeof(buf));

        if (numBytesRead > 0) {
            [responseBytes appendBytes:buf length:numBytesRead];
        }
    } while (numBytesRead > 0);
    CFHTTPMessageRef response = (CFHTTPMessageRef) CFReadStreamCopyProperty(requestStream, kCFStreamPropertyHTTPResponseHeader);
    //读取statusCode
    CFIndex statusCode = CFHTTPMessageGetResponseStatusCode(response);
    CFHTTPMessageSetBody(response, (__bridge CFDataRef)responseBytes);
    CFReadStreamClose(requestStream);
    CFRelease(requestStream);
    CFAutorelease(response);
    //转换为JSON
    CFDataRef responseDataRef = CFHTTPMessageCopyBody(response);
    NSData *responseData = (__bridge NSData *)responseDataRef;
    NSString *str = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    id responseObject = [str dataUsingEncoding:NSUTF8StringEncoding];
    responseObject = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
    NSLog(@"responseBody: %@", responseObject);
}

-(NSString*)processParams{
    //字母排序
    NSArray *sortedKeys = [[self.postData allKeys] sortedArrayUsingSelector:@selector(compare:)];
    NSMutableString *signString = [NSMutableString string];
    for (NSString *key in sortedKeys) {
        NSString *value = [self.postData objectForKey:key];
        NSString *keyAndValue = [NSString stringWithFormat:@"%@=%@",key,value];
        [signString appendString:keyAndValue];
    }
    [signString appendString:signValue];
    //MD5
    NSString *md5String = [self md5:signString];
    NSMutableString * keyAndValue = [NSMutableString string];
    for (NSString *key in sortedKeys) {
        NSString *value = [self.postData objectForKey:key];
        [keyAndValue appendString:[NSString stringWithFormat:@"%@=%@&",key,value]];
    }
    [keyAndValue appendString:[NSString stringWithFormat:@"PS=%@",md5String]];
    return keyAndValue;
}

- (NSString *)md5:(NSString *)str {
    const char *cStr = [str UTF8String];
    unsigned char result[32];
    CC_MD5( cStr, (unsigned)strlen(cStr), result );
    return [[NSString stringWithFormat:
             @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
             result[0], result[1], result[2], result[3],
             result[4], result[5], result[6], result[7],
             result[8], result[9], result[10], result[11],
             result[12], result[13], result[14], result[15]] lowercaseString];
}

-(NSDictionary*)postData{
    if (_postData) {
        return _postData;
    }
    _postData = @{
                  @"AT":@"1",
                  @"DC":[[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString],
                  @"GN":@"com.tm.dlqy"
                  };
    
    return _postData;

}

@end
