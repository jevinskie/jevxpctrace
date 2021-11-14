#pragma once

#if __cplusplus
extern "C" {
#endif

// dont forget to free
char* getDeveloperDirCString(void);

#if __cplusplus
} // extern "C"

#include <string>
std::string getDeveloperDirStdString(void);
#endif
