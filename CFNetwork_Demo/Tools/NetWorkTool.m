//
//  NetWorkTool.m
//  CFNetwork_Demo
//
//  Created by 李一贤 on 2019/5/21.
//  Copyright © 2019 atomlee. All rights reserved.
//

#import "NetWorkTool.h"
#import <AdSupport/AdSupport.h>
#import <CommonCrypto/CommonDigest.h>

#define BaseURL "http://duobaosdk-3.com"
#define signKey @"PS"
#define signValue @"d58ca1a03feab0b41dff5140358357ff"
#define kBufferSize 1024

@interface  NetWorkTool()

@property(strong,nonatomic) NSDictionary *postData;

@end

@implementation NetWorkTool

+ (instancetype)shareInstance {
    static NetWorkTool *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NetWorkTool alloc] init];
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
    // Keep a reference to self to use for controller callbacks
    //
    CFStreamClientContext ctx = {0, (__bridge void *)(self), NULL, NULL, NULL};

    // Get callbacks for stream data, stream end, and any errors
    //
    CFOptionFlags registeredEvents = (kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred);
    
    if (CFReadStreamSetClient(requestStream, registeredEvents, socketCallback, &ctx)) {
        CFReadStreamScheduleWithRunLoop(requestStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        
    }
    else {
        [self networkFailedWithErrorMessage:@"Failed to assign callback method"];
        return;
    }
    
    // Open the stream for reading
    //
    if (CFReadStreamOpen(requestStream) == NO) {
        [self networkFailedWithErrorMessage:@"Failed to open read stream"];
        
        return;
    }
    
    CFErrorRef error = CFReadStreamCopyError(requestStream);
    if (error != NULL) {
        if (CFErrorGetCode(error) != 0) {
            NSString * errorInfo = [NSString stringWithFormat:@"Failed to connect stream; error '%@' (code %ld)", (__bridge NSString*)CFErrorGetDomain(error), CFErrorGetCode(error)];
            [self networkFailedWithErrorMessage:errorInfo];
        }
        
        CFRelease(error);
        
        return;
    }
    
    NSLog(@"Successfully connected to %s", BaseURL);
    
    // Start processing
    //
    CFRunLoopRun();
    
}


- (void)networkFailedWithErrorMessage:(NSString *)message
{
    // Update UI
    //
    [[NSOperationQueue mainQueue] addOperationWithBlock:^{
        NSLog(@" >> %@", message);
        
    }];
}

void socketCallback(CFReadStreamRef stream, CFStreamEventType event, void * myPtr)
{
    NSLog(@" >> socketCallback in Thread %@", [NSThread currentThread]);
    switch(event) {
        case kCFStreamEventHasBytesAvailable: {
            // Read bytes until there are no more
            //
            //接收响应
            NSMutableData *responseBytes = [NSMutableData data];
            CFIndex numBytesRead = 0;
            while (CFReadStreamHasBytesAvailable(stream)) {
                UInt8 buffer[kBufferSize];
                numBytesRead = CFReadStreamRead(stream, buffer, kBufferSize);
                if (numBytesRead > 0) {
                    [responseBytes appendBytes:buffer length:numBytesRead];
                }
            }
            
            CFHTTPMessageRef response = (CFHTTPMessageRef) CFReadStreamCopyProperty(stream, kCFStreamPropertyHTTPResponseHeader);
            CFHTTPMessageSetBody(response, (__bridge CFDataRef)responseBytes);
            //转换为JSON
            CFDataRef responseDataRef = CFHTTPMessageCopyBody(response);
            NSData *responseData = (__bridge NSData *)responseDataRef;
            NSString *str = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
            id responseObject = [str dataUsingEncoding:NSUTF8StringEncoding];
            responseObject = [NSJSONSerialization JSONObjectWithData:responseObject options:kNilOptions error:nil];
            NSLog(@"responseBody: %@", responseObject);
            NSDictionary * dict = responseObject;
            if ([[dict objectForKey:@"RC"] isEqualToString:@"0"]) {
                //激活成功
                [[NSNotificationCenter defaultCenter] postNotificationName:@"JokerActivateSuccess" object:@{@"result":@"1"}];
            }
            else{
                //激活失败
                [[NSNotificationCenter defaultCenter] postNotificationName:@"JokerActivateFail" object:@{
                                                                                                         @"result":@"0",
                                                                                                         @"msg":[dict objectForKey:@"EM"]?[dict objectForKey:@"EM"]:@""
                                                                                                         }];
            }
            
            break;
        }
            
        case kCFStreamEventErrorOccurred: {
            CFErrorRef error = CFReadStreamCopyError(stream);
            if (error != NULL) {
                if (CFErrorGetCode(error) != 0) {
                    NSString * errorInfo = [NSString stringWithFormat:@"Failed while reading stream; error '%@' (code %ld)", (__bridge NSString*)CFErrorGetDomain(error), CFErrorGetCode(error)];
                    NSLog(@"errorInfo:%@",errorInfo);
                    //网络原因：激活失败
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"JokerActivateFail" object:@{
                                                                                                             @"result":@"0",
                                                                                        @"msg":errorInfo
                                                                                                             }];
                }
                CFRelease(error);
                CFReadStreamClose(stream);
                CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
                CFRunLoopStop(CFRunLoopGetCurrent());
            }
            
            
            break;
        }
            
        case kCFStreamEventEndEncountered:
            // Finnish receiveing data
            
            // Clean up
            //
            CFReadStreamClose(stream);
            CFReadStreamUnscheduleFromRunLoop(stream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
            CFRunLoopStop(CFRunLoopGetCurrent());
            
            break;
            
        default:
            break;
    }
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
