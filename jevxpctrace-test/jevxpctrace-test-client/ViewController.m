//
//  ViewController.m
//  jevxpctrace-test-client
//
//  Created by Jevin Sweval on 11/12/21.
//

#include <AssertMacros.h>

#import "ViewController.h"


#import <jevxpctrace-test-service/jevxpctrace_test_serviceProtocol.h>

#include <CaptainHook.h>
#include <CoreSymbolication.h>
#include <execinfo.h>


#define YESNO(x) ((x) ? @"YES" : @"NO")

BOOL doBP;

CHDeclareClass(NSXPCDecoder);

@interface NSXPCDecoder : NSXPCCoder
- (int)__decodeXPCObject:(xpc_object_t)root
    allowingSimpleMessageSend:(BOOL)allowSimpleMessageSend
                outInvocation:(NSInvocation **)invocation
                 outArguments:(id *)arguments
         outArgumentsMaxCount:(NSUInteger)maxArgCount
           outMethodSignature:(NSMethodSignature **)outMethodSignature
                  outSelector:(SEL *)outSelector
                      isReply:(BOOL)isReply
                replySelector:(SEL)replySelector
                    interface:(NSXPCInterface *)interface;
@end

CHConstructor { CHLoadLateClass(NSXPCDecoder); }

#define JEVTRACE_CS_HEADER 0x0d7029bau
#define JEVTRACE_CS_FOOTER 0x2845443e

bool getJevTraceBuf(void *sp, uint8_t **begin, uint8_t **end) {
    bool isGood = false;

    __Require_Action(begin, finish, isGood = false);
    uint32_t *p = (uint32_t *)sp;
    while (*p != JEVTRACE_CS_HEADER) {
        ++p;
    }
    *begin = (uint8_t *)p;

    __Require_Action(end, finish, isGood = false);
    while (*p != JEVTRACE_CS_FOOTER) {
        ++p;
    }
    *end = (uint8_t *)(p + 1);

    isGood = true;

finish:
    return isGood;
}

void putCallstackOnStack(void) {
    void *bt_buf[128] = {NULL};
    int num_frames = backtrace(bt_buf, sizeof(bt_buf) / sizeof(void*));
    assert(num_frames > 0);

    CSSymbolicatorRef symbolicator = CSSymbolicatorCreateWithTask(mach_task_self());
    assert(!CSIsNull(symbolicator));

    for (int ret_addr_idx = 0; ret_addr_idx < num_frames; ++ret_addr_idx) {
        void *ret_addr = bt_buf[ret_addr_idx];
        CSSymbolRef sym = CSSymbolicatorGetSymbolWithAddressAtTime(symbolicator, (vm_address_t)ret_addr, kCSNow);
        NSLog(@"symbol: %@", CSSymbolCopyDescriptionWithIndent(sym, 0));
//        CSRange rng = CSSymbolGetRange(sym);
//        gDyld_addr = rng.location;
    }

    //    uint8_t buf[16*1024*8];
    uint8_t buf[32];
    memset(buf, 0, sizeof(buf));

    uint32_t *header_p = (uint32_t *)buf;
    uint32_t *footer_p = (uint32_t *)(buf + sizeof(buf) - sizeof(uint32_t));
    *header_p = JEVTRACE_CS_HEADER;
    *footer_p = JEVTRACE_CS_FOOTER;

    void *sp = NULL;

    __asm __volatile("mov %[_sp], sp\n\t"
                     : [_sp] "=r"(sp) /* outputs */
    );

    NSLog(@"sp: %p", sp);
    uint8_t *tb = NULL;
    uint8_t *te = NULL;
    bool gotTraceBuf = getJevTraceBuf(sp, &tb, &te);
    NSLog(@"gotTraceBuf: %@ tb: %p te: %p", YESNO(gotTraceBuf), tb, te);
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

    NSXPCInterface *interface =
        [NSXPCInterface interfaceWithProtocol:@protocol(DummyProtocol)];

    NSXPCDecoder *decoder = [[CHClass(NSXPCDecoder) alloc] init];
    res = [decoder __decodeXPCObject:dict
           allowingSimpleMessageSend:YES
                       outInvocation:&invoc
                        outArguments:args
                outArgumentsMaxCount:32
                  outMethodSignature:&sig
                         outSelector:&sel
                             isReply:NO
                       replySelector:nil
                           interface:interface];
    NSLog(@"res: %d invoc: %@ args[0]: %@ args[1]: %@ args[2]: %@ args[3]: %@ "
          @"sig: %@ sel: %@",
          res, invoc, args[0], args[1], args[2], args[3], sig,
          NSStringFromSelector(sel));
}

@implementation ViewController

- (void)xpcTest {
    NSXPCConnection *xpcConn = [[NSXPCConnection alloc]
        initWithServiceName:@"vin.je.jevxpctrace-test-service"];
    xpcConn.remoteObjectInterface = [NSXPCInterface
        interfaceWithProtocol:@protocol(jevxpctrace_test_serviceProtocol)];
    [xpcConn resume];

    id proxy = xpcConn.remoteObjectProxy;

    doBP = YES;
    [proxy upperCaseString:@"hello"
                 withReply:^(NSString *aString) {
                   // We have received a response. Update our text field, but do
                   // it on the main thread.
                   NSLog(@"Result string was: %@", aString);
                   putCallstackOnStack();
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
