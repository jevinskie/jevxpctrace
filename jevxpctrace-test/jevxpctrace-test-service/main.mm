//
//  main.m
//  jevxpctrace-test-service
//
//  Created by Jevin Sweval on 11/12/21.
//

#import "jevxpctrace_test_service.h"
#import <Foundation/Foundation.h>

#include <fridacpp.h>

@interface ServiceDelegate : NSObject <NSXPCListenerDelegate>
@end

@implementation ServiceDelegate

- (BOOL)listener:(NSXPCListener*)listener shouldAcceptNewConnection:(NSXPCConnection*)newConnection
{
    // This method is where the NSXPCListener configures, accepts, and resumes a
    // new incoming NSXPCConnection.

    // Configure the connection.
    // First, set the interface that the exported object implements.
    newConnection.exportedInterface =
        [NSXPCInterface interfaceWithProtocol:@protocol(jevxpctrace_test_serviceProtocol)];

    // Next, set the object that the connection exports. All messages sent on
    // the connection to this service will be sent to the exported object to
    // handle. The connection retains the exported object.
    jevxpctrace_test_service* exportedObject = [jevxpctrace_test_service new];
    newConnection.exportedObject = exportedObject;

    // Resuming the connection allows the system to deliver more incoming
    // messages.
    [newConnection resume];

    // Returning YES from this method tells the system that you have accepted
    // this connection. If you want to reject the connection for some reason,
    // call -invalidate on the connection and return NO.
    return YES;
}

@end

class _xpc_connection_call_event_handler_hook_t : public InvocationListener {

public:
    void on_enter(GumInvocationContext* context) override
    {
        xpc_object_t event = (__bridge xpc_object_t)gum_invocation_context_get_nth_argument(context, 1);
        size_t hash = event ? xpc_hash(event) : 0;
        NSLog(@"%s %@ hash: 0x%016zx", __PRETTY_FUNCTION__, event, hash);
    }
    void on_leave(GumInvocationContext* context) override
    {
        //        NSLog(@"%s", __func__);
    }
};

_xpc_connection_call_event_handler_hook_t* _xpc_connection_call_event_handler_hook;

Intercepter* interceptor;

void installHook(void)
{
    interceptor = new Intercepter();
    _xpc_connection_call_event_handler_hook = new _xpc_connection_call_event_handler_hook_t();
    gpointer _xpc_connection_call_event_handler_fptr
        = GSIZE_TO_POINTER(gum_module_find_symbol_by_name("libxpc.dylib", "_xpc_connection_call_event_handler"));
    interceptor->attach(_xpc_connection_call_event_handler_fptr, _xpc_connection_call_event_handler_hook, nullptr);
}

int main(int argc, const char* argv[])
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        installHook();
    });

    // Create the delegate for the service.
    ServiceDelegate* delegate = [ServiceDelegate new];

    // Set up the one NSXPCListener for this service. It will handle all
    // incoming connections.
    NSXPCListener* listener = [NSXPCListener serviceListener];
    listener.delegate = delegate;

    // Resuming the serviceListener starts this service. This method does not
    // return.
    [listener resume];
    return 0;
}
