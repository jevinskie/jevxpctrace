#include "libxcselectpp.h"

#import <Foundation/Foundation.h>
#include <limits.h>
using namespace std::string_literals;

extern "C" bool xcselect_get_developer_dir_path(char* path, int path_sz, bool* unk1, bool* unk2, bool* unk3);

char* getDeveloperDirCString(void)
{
    char* path = (char*)malloc(PATH_MAX);
    if (!path) {
        return nullptr;
    }
    memset(path, 0, PATH_MAX);
    bool unk1, unk2, unk3;
    bool res = xcselect_get_developer_dir_path(path, PATH_MAX, &unk1, &unk2, &unk3);
    if (!res) {
        free(path);
        return nullptr;
    }
    return path;
}

NSString* getDeveloperDirNSString(void)
{
    char* path = getDeveloperDirCString();
    NSString* res = @(path);
    free(path);
    return res;
}

std::string getDeveloperDirStdString(void)
{
    char* path = getDeveloperDirCString();
    if (!path) {
        return ""s;
    }
    return std::string { path };
}
