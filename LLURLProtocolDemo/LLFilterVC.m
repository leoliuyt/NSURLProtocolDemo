//
//  LLFilterVC.m
//  LLURLProtocolDemo
//
//  Created by leoliu on 16/8/7.
//  Copyright © 2016年 LL. All rights reserved.
//

#import "LLFilterVC.h"
@interface LLFilterVC()<UIWebViewDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end
@implementation LLFilterVC

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSURL *url = [NSURL URLWithString:@"https://www.baidu.com"];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    [self.webView loadRequest:request];
    self.webView.delegate = self;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    
}
- (void)webView:(UIWebView *)webView didFailLoadWithError:(nullable NSError *)error
{
    NSLog(@"%@",[error localizedDescription]);
}
@end
