#pragma once

// dont forget to free
char* getDeveloperDirCString(void);

#if __OBJC__
@class NSString;
NSString* getDeveloperDirNSString(void);
#endif

#if __cplusplus
#include <string>
std::string getDeveloperDirStdString(void);
#endif
