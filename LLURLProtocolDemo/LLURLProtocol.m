//
//  LLURLProtocol.m
//  LLURLProtocolDemo
//
//  Created by leoliu on 16/8/7.
//  Copyright © 2016年 LL. All rights reserved.
//

#import "LLURLProtocol.h"

static NSString * kOurRecursiveRequestFlagProperty = @"com.leoliu.LLURLProtocol";

@interface LLURLProtocol()<NSURLConnectionDelegate,NSURLSessionDelegate>

@property (nonatomic, strong) NSURLConnection *connection;
@property (nonatomic, strong) NSURLSessionDataTask *task;
@end

@implementation LLURLProtocol

//决定了这个协议是否能处理过来的request
//抽象方法子类必须提供实现
//可以在该方法中做过滤，哪些请求需要处理就返回YES，不需要处理返回NO
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [self filterRequest:request];
}

//返回统一规范的请求格式
//抽象方法子类必须提供实现
//可以在该方法中添加Header、请求重定向
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    mutableReqeust = [self redirectHostInRequset:mutableReqeust];
    return mutableReqeust;
}

//主要判断两个request是否相同,如果相同使用缓存数据，通常只需调用父类实现
+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b
{
    return [super requestIsCacheEquivalent:a toRequest:b];
}

//开始加载request
//抽象方法子类必须提供实现
//可以在该方法中处理缓存
- (void)startLoading
{
    NSMutableURLRequest *mutableReqeust = [[self request] mutableCopy];
    //标示改request已经处理过了，防止无限循环
    [NSURLProtocol setProperty:@YES forKey:kOurRecursiveRequestFlagProperty inRequest:mutableReqeust];
    
    
    //可以直接返回本地的模拟数据，进行测试
    BOOL enableDebug = NO;
    
    if (enableDebug) {
        
        NSString *str = @"测试数据";
        
        NSData *data = [str dataUsingEncoding:NSUTF8StringEncoding];
        
        NSURLResponse *response = [[NSURLResponse alloc] initWithURL:mutableReqeust.URL
                                                            MIMEType:@"text/plain"
                                               expectedContentLength:data.length
                                                    textEncodingName:nil];
        [self.client URLProtocol:self
              didReceiveResponse:response
              cacheStoragePolicy:NSURLCacheStorageNotAllowed];
        
        [self.client URLProtocol:self didLoadData:data];
        [self.client URLProtocolDidFinishLoading:self];
    }
    else {
        self.connection = [NSURLConnection connectionWithRequest:mutableReqeust delegate:self];
    }
    
//    //支持Session
//    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
//    //必须用自己的协议子类来配置session 否则 看不到重定向
//    config.protocolClasses = @[self];
//    self.task = [[NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:[NSOperationQueue mainQueue]] dataTaskWithRequest:self.request];
//    [self.task resume];
}

//停止加载request
- (void)stopLoading
{
    if(self.connection) {
        [self.connection cancel];
        self.connection = nil;
    }
    
//    if (self.task) {
//        [self.task cancel];
//        self.task = nil;
//    }
}

//+ (BOOL)canInitWithTask:(NSURLSessionTask *)task
//{
//    return YES;
//}

//MARK:NSURLConnectionDelegate
- (void) connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
}

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection {
    [self.client URLProtocolDidFinishLoading:self];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [self.client URLProtocol:self didFailWithError:error];
}

//MARK:Custom

//过滤请求
+ (BOOL)filterRequest:(NSURLRequest *)request
{
    BOOL        shouldAccept;
    NSURL *     url;
    NSString *  scheme;
    
    shouldAccept = (request != nil);
    if (shouldAccept) {
        url = [request URL];
        shouldAccept = (url != nil);
    }

    // 减少重复请求
    if (shouldAccept) {
        shouldAccept = ([self propertyForKey:kOurRecursiveRequestFlagProperty inRequest:request] == nil);
    }
    
    if (shouldAccept) {
        scheme = [[url scheme] lowercaseString];
        shouldAccept = (scheme != nil);
    }
    
    if (shouldAccept) {
        shouldAccept = YES && ([scheme isEqual:@"http"]||[scheme isEqual:@"https"]);
    }
    if (shouldAccept) {
        //过滤条件
        NSArray <NSString *>*array = @[
                                       @"http://www.baidu.com",
                                       ];
        __block BOOL addHeader = YES;
        [array enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([request.URL.host rangeOfString:obj].length > 0) {
                addHeader = NO;
                *stop = YES;
            }
        }];
        shouldAccept = addHeader;
    }
    return shouldAccept;
}

//添加Header、请求重定向
+ (NSMutableURLRequest*)redirectHostInRequset:(NSMutableURLRequest*)request
{
    if ([request.URL host].length == 0) {
        return request;
    }
    
    NSString *originUrlString = [request.URL absoluteString];
    NSString *originHostString = [request.URL host];
    NSRange hostRange = [originUrlString rangeOfString:originHostString];
    if (hostRange.location == NSNotFound) {
        return request;
    }
    //定向到友盟主页
    NSString *ip = @"www.umeng.com";
    
    // 替换域名
    NSString *urlString = [originUrlString stringByReplacingCharactersInRange:hostRange withString:ip];
    NSURL *url = [NSURL URLWithString:urlString];
    request.URL = url;
    
    //添加header
    [request addValue:@"11111" forHTTPHeaderField:@"userid"];
    return request;
}


//MARK:NSURLSessionDelegate
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)newRequest completionHandler:(void (^)(NSURLRequest *))completionHandler
//{
//    NSMutableURLRequest *    redirectRequest;
//    
//    redirectRequest = [newRequest mutableCopy];
//    [[self class] removePropertyForKey:kOurRecursiveRequestFlagProperty inRequest:redirectRequest];
//    
//    // Tell the client about the redirect.
//    
//    [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
//    
//    [self.task cancel];
//    
//    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
//}
//
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
//{
//    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
//}
//
//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler
//{
////    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:cacheStoragePolicy];
//    
//    completionHandler(NSURLSessionResponseAllow);
//}
//
//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
//{
//    [[self client] URLProtocol:self didLoadData:data];
//}
//
//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask willCacheResponse:(NSCachedURLResponse *)proposedResponse completionHandler:(void (^)(NSCachedURLResponse *))completionHandler
//{
//    completionHandler(proposedResponse);
//}
//
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
//{
//    if (error == nil) {
//        [[self client] URLProtocolDidFinishLoading:self];
//    } else if ( [[error domain] isEqual:NSURLErrorDomain] && ([error code] == NSURLErrorCancelled) ) {
//
//    } else {
//        [[self client] URLProtocol:self didFailWithError:error];
//    }
//}

@end
