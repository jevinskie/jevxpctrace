//
//  jevxpctrace_test_service.h
//  jevxpctrace-test-service
//
//  Created by Jevin Sweval on 11/12/21.
//

#import "jevxpctrace_test_serviceProtocol.h"
#import <Foundation/Foundation.h>

// This object implements the protocol which we have defined. It provides the
// actual behavior for the service. It is 'exported' by the service to make it
// available to the process hosting the service over an NSXPCConnection.
@interface jevxpctrace_test_service
    : NSObject <jevxpctrace_test_serviceProtocol>
@end
