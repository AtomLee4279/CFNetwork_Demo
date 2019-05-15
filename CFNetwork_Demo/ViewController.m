//
//  ViewController.m
//  CFNetwork_Demo
//
//  Created by 李一贤 on 2019/5/14.
//  Copyright © 2019 atomlee. All rights reserved.
//

#import "ViewController.h"
#import "NetworkHelper.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    
    // Do any additional setup after loading the view.
}

- (IBAction)testNetWorkBtnDidClick:(id)sender {
    
    [[NetworkHelper shareInstance] postUrl];
}

@end
