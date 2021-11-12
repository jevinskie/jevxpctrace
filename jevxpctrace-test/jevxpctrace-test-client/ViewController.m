//
//  ViewController.m
//  jevxpctrace-test-client
//
//  Created by Jevin Sweval on 11/12/21.
//

#import "ViewController.h"

#import <jevxpctrace-test-service/jevxpctrace_test_serviceProtocol.h>

@implementation ViewController

- (void)xpcTest {
    NSXPCConnection *xpcConn = [[NSXPCConnection alloc] initWithServiceName:@"vin.je.jevxpctrace-test-service"];
    xpcConn.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(jevxpctrace_test_serviceProtocol)];
    [xpcConn resume];

    [[xpcConn remoteObjectProxy] upperCaseString:@"hello" withReply:^(NSString *aString) {
        // We have received a response. Update our text field, but do it on the main thread.
        NSLog(@"Result string was: %@", aString);
        [xpcConn invalidate];
    }];

}

- (void)viewDidLoad {
    [super viewDidLoad];

    [self xpcTest];
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
