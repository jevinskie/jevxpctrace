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
#include <xpc/xpc.h>

#include <gum/gum.h>
#include <gumpp/gumpp.hpp>

#define YESNO(x) ((x) ? @"YES" : @"NO")

BOOL doBP;

CHDeclareClass(NSXPCDecoder);

@interface NSXPCDecoder : NSXPCCoder
- (int)__decodeXPCObject:(xpc_object_t)root
    allowingSimpleMessageSend:(BOOL)allowSimpleMessageSend
                outInvocation:(NSInvocation**)invocation
                 outArguments:(id*)arguments
         outArgumentsMaxCount:(NSUInteger)maxArgCount
           outMethodSignature:(NSMethodSignature**)outMethodSignature
                  outSelector:(SEL*)outSelector
                      isReply:(BOOL)isReply
                replySelector:(SEL)replySelector
                    interface:(NSXPCInterface*)interface;
@end

CHConstructor
{
    CHLoadLateClass(NSXPCDecoder);
}

#define JEVTRACE_CS_HEADER 0x0d7029bau
#define JEVTRACE_CS_FOOTER 0x2845443eu

__attribute__((no_sanitize("address"))) bool getJevTraceBuf(void* sp, uint8_t** begin, uint8_t** end)
{
    bool isGood = false;

    if (!sp || !begin || !end) {
        return false;
    }

    uint32_t* p = (uint32_t*)sp;
    while (*p != JEVTRACE_CS_HEADER) {
        ++p;
    }
    *begin = (uint8_t*)p;

    while (*p != JEVTRACE_CS_FOOTER) {
        ++p;
    }
    *end = (uint8_t*)(p + 1);

    isGood = true;

finish:
    return isGood;
}

void putCallstackOnStack(void)
{
    void* bt_buf[128] = { NULL };
    int num_frames = backtrace(bt_buf, sizeof(bt_buf) / sizeof(void*));
    assert(num_frames > 0);

    CSSymbolicatorRef cs = CSSymbolicatorCreateWithTask(mach_task_self());
    assert(!CSIsNull(cs));

    NSMutableArray<NSDictionary*>* bt = [NSMutableArray arrayWithCapacity:128];

    for (int ret_addr_idx = 0; ret_addr_idx < num_frames; ++ret_addr_idx) {
        uintptr_t ret_addr = (uintptr_t)bt_buf[ret_addr_idx];
        CSSymbolRef sym = CSSymbolicatorGetSymbolWithAddressAtTime(cs, (vm_address_t)ret_addr, kCSNow);
        CSSymbolOwnerRef sym_owner = CSSymbolGetSymbolOwner(sym);
        const char* mod_name = CSSymbolOwnerGetName(sym_owner);
        //        CSSymbolRef sym = CSSourceInfoGetSymbol(info);
        CSRange rng = CSSymbolGetRange(sym);
        const char* sym_name = CSSymbolGetName(sym);
        uintptr_t off = ret_addr - (uintptr_t)rng.location;

        NSDictionary* entry =
            @{@"addr" : @(rng.location),
                @"name" : @(sym_name),
                @"off" : @(off),
                @"mod" : @(mod_name)};
        bt[ret_addr_idx] = entry;

        //        NSLog(@"symbol: %s %p off: 0x%tx", sym_name, (const void
        //        *)rng.location, off);
    }
    //    NSLog(@"bt: %@", bt);

    NSError* error = nil;
    NSData* btBPlist = [NSPropertyListSerialization dataWithPropertyList:bt
                                                                  format:NSPropertyListBinaryFormat_v1_0
                                                                 options:NSPropertyListImmutable
                                                                   error:&error];
    assert(!error);
    uint8_t buf[16 * 1024 * 8];
    //    uint8_t buf[32];
    memset(buf, 0, sizeof(buf));

    uint32_t* header_p = (uint32_t*)buf;
    uint32_t* size_p = header_p + 1;
    uint8_t* buf_p = (uint8_t*)(size_p + 1);
    uint32_t* footer_p = (uint32_t*)(buf + sizeof(buf) - sizeof(uint32_t));
    *header_p = JEVTRACE_CS_HEADER;
    *size_p = (uint32_t)btBPlist.length;
    //    assert(btBPlist.length < sizeof(buf) - 3*sizeof(uint32_t));
    memcpy(buf_p, btBPlist.bytes, btBPlist.length);
    *footer_p = JEVTRACE_CS_FOOTER;

    void* sp = NULL;

    __asm __volatile("mov %[_sp], sp\n\t"
                     : [_sp] "=r"(sp) /* outputs */
    );

    NSLog(@"sp: %p", sp);
    uint8_t* tb = NULL;
    uint8_t* te = NULL;
    bool gotTraceBuf = getJevTraceBuf(sp, &tb, &te);
    NSLog(@"gotTraceBuf: %@ tb: %p te: %p", YESNO(gotTraceBuf), tb, te);
    if (gotTraceBuf) {
        uint32_t* found_header_p = (uint32_t*)tb;
        uint32_t* found_size_p = found_header_p + 1;
        uint8_t* found_buf_p = (uint8_t*)(found_size_p + 1);
        NSLog(@"founBt length: %u", *found_size_p);
        NSData* foundBuf = [NSData dataWithBytes:found_buf_p length:*found_size_p];
        NSDictionary* foundBt = [NSPropertyListSerialization propertyListWithData:foundBuf
                                                                          options:NSPropertyListImmutable
                                                                           format:nil
                                                                            error:&error];
        assert(!error);
        NSLog(@"foundBt: %@", foundBt);
    }
}

@protocol DummyProtocol
@end

void dumpXPCObject(xpc_object_t dict)
{
    //    doBP = NO;
    int res = -1;
    NSInvocation* invoc;
    __autoreleasing id args[32] = { nil };
    NSMethodSignature* sig;
    SEL sel;

    NSLog(@"dict: %@", dict);

    xpc_object_t root = xpc_dictionary_get_value(dict, "root");
    NSLog(@"root: %@", root);

    const void* root_buf = xpc_data_get_bytes_ptr(root);
    size_t root_len = xpc_data_get_length(root);
    NSLog(@"root_buf: %p root_len: %zu", root_buf, root_len);

    NSXPCInterface* interface = [NSXPCInterface interfaceWithProtocol:@protocol(DummyProtocol)];

    NSXPCDecoder* decoder = [[CHClass(NSXPCDecoder) alloc] init];
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
        res, invoc, args[0], args[1], args[2], args[3], sig, NSStringFromSelector(sel));
}

class xpc_connection_send_message_with_reply_hook_t : public Gum::InvocationListener {
public:
    virtual void on_enter(Gum::InvocationContext* context)
    {
        xpc_object_t msg = context->get_nth_argument_bridged<xpc_object_t>(1);
        size_t hash = msg ? xpc_hash(msg) : 0;
        NSLog(@"%s %@ hash: 0x%016zx", __PRETTY_FUNCTION__, msg, hash);
    }

    virtual void on_leave(Gum::InvocationContext* context)
    {
        //      NSLog(@"%s", __PRETTY_FUNCTION__);
    }
};

static Gum::Interceptor* interceptor;

static xpc_connection_send_message_with_reply_hook_t* xpc_connection_send_message_with_reply_hook;

static void installHook(void)
{
    interceptor = Gum::Interceptor_obtain();
    xpc_connection_send_message_with_reply_hook = new xpc_connection_send_message_with_reply_hook_t;
    gpointer xpc_connection_send_message_with_reply_fptr
        = GSIZE_TO_POINTER(gum_module_find_symbol_by_name("libxpc.dylib", "xpc_connection_send_message_with_reply"));
    NSLog(@"xpc_connection_send_message_with_reply_fptr: %p", (void*)xpc_connection_send_message_with_reply_fptr);
    interceptor->attach(reinterpret_cast<void*>(xpc_connection_send_message_with_reply_fptr),
        xpc_connection_send_message_with_reply_hook, nullptr);
    //    interceptor->detach (&listener);
}

@implementation ViewController

- (void)xpcTest
{
    installHook();

    NSXPCConnection* xpcConn = [[NSXPCConnection alloc] initWithServiceName:@"vin.je.jevxpctrace-test-service"];
    xpcConn.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:@protocol(jevxpctrace_test_serviceProtocol)];
    [xpcConn resume];

    id proxy = xpcConn.remoteObjectProxy;

    doBP = YES;
    [proxy upperCaseString:@"hello"
                 withReply:^(NSString* aString) {
                     // We have received a response. Update our text field, but do
                     // it on the main thread.
                     NSLog(@"Result string was: %@", aString);
                     putCallstackOnStack();
                     [xpcConn invalidate];
                 }];
    doBP = NO;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self xpcTest];
}

- (void)setRepresentedObject:(id)representedObject
{
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}

@end
