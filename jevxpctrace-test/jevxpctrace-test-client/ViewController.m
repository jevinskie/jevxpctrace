//
//  ViewController.m
//  jevxpctrace-test-client
//
//  Created by Jevin Sweval on 11/12/21.
//

#import "ViewController.h"

#import <jevxpctrace-test-service/jevxpctrace_test_serviceProtocol.h>

#include <CaptainHook.h>

BOOL doBP;

CHDeclareClass(NSXPCDecoder);

@interface NSXPCDecoder : NSXPCCoder
- (int)__decodeXPCObject:(xpc_object_t)root allowingSimpleMessageSend:(BOOL)allowSimpleMessageSend outInvocation:(NSInvocation **)invocation outArguments:(id *)arguments outArgumentsMaxCount:(NSUInteger)maxArgCount outMethodSignature:(NSMethodSignature **)outMethodSignature outSelector:(SEL *)outSelector isReply:(BOOL)isReply replySelector:(SEL)replySelector interface:(NSXPCInterface *)interface;
@end

CHConstructor {
    CHLoadLateClass(NSXPCDecoder);
}


@protocol DummyProtocol
@end

void dumpXPCObject(xpc_object_t dict) {
//    doBP = NO;
    int res = -1;
    NSInvocation *invoc;
    __autoreleasing id args[32] = {nil};
    NSMethodSignature *sig;
    SEL sel;

    NSLog(@"dict: %@", dict);

    xpc_object_t root = xpc_dictionary_get_value(dict, "root");
    NSLog(@"root: %@", root);

    const void *root_buf = xpc_data_get_bytes_ptr(root);
    size_t root_len = xpc_data_get_length(root);
    NSLog(@"root_buf: %p root_len: %zu", root_buf, root_len);

    NSXPCInterface *interface = [NSXPCInterface interfaceWithProtocol:@protocol(DummyProtocol)];

    NSXPCDecoder *decoder = [[CHClass(NSXPCDecoder) alloc] init];
    res = [decoder __decodeXPCObject:dict allowingSimpleMessageSend:YES outInvocation:&invoc outArguments:args outArgumentsMaxCount:32 outMethodSignature:&sig outSelector:&sel isReply:NO replySelector:nil interface:interface];
    NSLog(@"res: %d invoc: %@ args[0]: %@ args[1]: %@ args[2]: %@ args[3]: %@ sig: %@ sel: %@", res, invoc, args[0], args[1], args[2], args[3], sig, NSStringFromSelector(sel));
}

@implementation ViewController

- (void)xpcTest {
    NSXPCConnection *xpcConn = [[NSXPCConnection alloc] initWithServiceName:@"vin.je.jevxpctrace-test-service"];
    xpcConn.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(jevxpctrace_test_serviceProtocol)];
    [xpcConn resume];

    id proxy = xpcConn.remoteObjectProxy;

    doBP = YES;
    [proxy upperCaseString:@"hello" withReply:^(NSString *aString) {
        // We have received a response. Update our text field, but do it on the main thread.
        NSLog(@"Result string was: %@", aString);
        [xpcConn invalidate];
    }];
    doBP = NO;
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
