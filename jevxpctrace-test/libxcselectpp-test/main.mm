//
//  main.m
//  libxcselectpp-test
//
//  Created by Jevin Sweval on 11/13/21.
//

#import <Foundation/Foundation.h>
#include <libxcselectpp.h>

int main(int argc, const char* argv[])
{
    @autoreleasepool {
        // insert code here...
        char* dev_dir_cstr = getDeveloperDirCString();
        NSLog(@"dir cstring: %s", dev_dir_cstr);
        free(dev_dir_cstr);
        NSLog(@"dir nsstring: %@", getDeveloperDirNSString());
        NSLog(@"dir std::string: %s", getDeveloperDirStdString().data());
    }
    return 0;
}
