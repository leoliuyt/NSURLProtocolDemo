# NSURLProtocol介绍

最近所做的项目中有这样一个需求，要求在所有的H5界面中的请求header头中添加用户id、手机号等信息，如果只是对H5界面中的一级请求（刚进H5的那次请求）添加header信息的话这个可以通过一下代码添加

```
 NSMutableURLRequest *mutableRequest = [[NSMutableURLRequest alloc]initWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:60];
[mutableRequest setValue:@"userId" forHTTPHeaderField:@"userId"];
[mutableRequest addValue:@"userId" forHTTPHeaderField:@"userId"];
[self.webView loadRequest:mutableRequest];
```
但是如果改请求结束后加载出界面后，点击该界面中的某一文章，继续跳转到下一界面时，这个新请求的header头中是不会加上我们想要的信息的，因为上面代码只能在加载第一屏界面的时候起作用，要想对所有请求都添加header的话，我们可以使用`NSURLProtocol`

## NSURLProtocol
`NSURLProtocol`是苹果URL加载系统的一部分，它能够让你去重新定义[URL Loading System](https://developer.apple.com/library/ios/documentation/Cocoa/Conceptual/URLLoadingSystem/URLLoadingSystem.html)的行为。苹果加载系统如下图所示
{% asset_img URL_Loading_System.png URL Loading System %}

## 使用场景
除了我遇到的使用场景外，`NSURLProtocol`还有以下使用场景：

- 拦截特定协议的网络请求
- 忽略网络请求，直接返回自定义的Response（可用用于web界面加载图片，缓存处理）
- 修改Request（请求地址，认证信息，header）（可用于请求重定向）

## 如何使用

### 继承创建子类
应为NSURLProtocol是一个抽象类，使用时必须继承`NSURLProtocol`在子类实现它的具体方法
### 注册继承自`NSURLProtocol`的类
通过调用`NSURLProtocol`的类方法实现注册

```
[NSURLProtocol registerClass:[LLURLProtocol class]];
```
### 根据需要实现NSURLProtocol中的方法

- `+ (BOOL)canInitWithRequest:(NSURLRequest *)request;`

```
//决定了这个协议是否能处理过来的request
//抽象方法子类必须提供实现
//可以在该方法中做过滤，哪些请求需要处理就返回YES，不需要处理返回NO
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    return [self filterRequest:request];
}

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

    // Decline our recursive requests.
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
```
- `+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request;`

```
//返回统一规范的请求格式
//抽象方法子类必须提供实现
//可以在该方法中添加Header、请求重定向 （我在实践中发现在iOS7上,这里修改后的request 在startLoading中请求的request还是原来的值，没有改变，所以我一般将修改head头放在startLoading方法中）
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    NSMutableURLRequest *mutableReqeust = [request mutableCopy];
    mutableReqeust = [self redirectHostInRequset:mutableReqeust];
    return mutableReqeust;
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
```

- `+ (BOOL)requestIsCacheEquivalent:(NSURLRequest *)a toRequest:(NSURLRequest *)b;`

```
//主要判断两个request是否相同,如果相同使用缓存数据，通常只需调用父类实现
```

- `- (void)startLoading;`

```
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
```

- `- (void)stopLoading;`

```
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
```


