//
//  jevxpctrace_test_service.m
//  jevxpctrace-test-service
//
//  Created by Jevin Sweval on 11/12/21.
//

#import "jevxpctrace_test_service.h"

@implementation jevxpctrace_test_service

// This implements the example protocol. Replace the body of this class with the
// implementation of this service's protocol.
- (void)upperCaseString:(NSString*)aString withReply:(void (^)(NSString*))reply
{
    NSString* response = [aString uppercaseString];
    reply(response);
}

@end
