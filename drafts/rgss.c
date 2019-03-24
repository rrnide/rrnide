/**
 * rgss.exe - the standalone rgss, work with rgss.dll
 * compile: gcc -W -Wall -m32 -std=c11 -s -O rgss.c -o rgss.exe
 * usage: rgss [-d path\to\rgss.dll] file.rb ...
 *     when no [-d dll] specified, it will try loading rgss.dll at the same
 *     path of rgss.exe
 * notice: can only get error message from rgss.dll. for backtrace, write
 *     rescue in ruby
 */

#include <stdio.h>
#include <wchar.h>
#include <string.h>
#include <windows.h>

#define assert_not_equal(fail, value) do {              \
        if ((fail) == (value)) errorp(__LINE__, #value);\
    } while (0)

void errorp(int l, char *s) {
    char *m, *b;
    int c = GetLastError();
    FormatMessage(0x1300, 0, c, 0x0400, (char*)&m, 0, 0);
    b = LocalAlloc(0x0040, lstrlen(m) + lstrlen(s) + 40);
    sprintf(b, "%d: %s\nFailed with code %d: %s", l, s, c, m);
    printf(b);
    LocalFree(m);
    LocalFree(b);
    ExitProcess(c);
}

#define SIZE 1048576
char buffer[SIZE];

int main(int argc, char **argv) {
    int start = 1;
    HMODULE lib;
    if (argc > 1) {
        if (strcmp(argv[1], "-d") == 0 && argc > 3) {
            assert_not_equal(0, lib = LoadLibrary(argv[2]));
            start = 3;
        } else {
            assert_not_equal(0, lib = LoadLibrary("RGSS301.dll"));
        }
    } else {
        printf("usage: %s [-d path/to/rgss.dll] file.rb ...\n", argv[0]);
        exit(0);
    }

    SetConsoleTitle("RGSS Console");
    long unsigned mode;
    HANDLE hStdout = GetStdHandle(STD_OUTPUT_HANDLE);
    GetConsoleMode(hStdout, &mode);
    SetConsoleMode(hStdout, mode | 4);

#define declare_func(name, ret, ...) \
    typedef ret (WINAPI *t##name)(__VA_ARGS__); \
    t##name name; \
    assert_not_equal(0, name = (t##name)GetProcAddress(lib, #name));

    declare_func(RGSSInitialize3, int);
    declare_func(RGSSEval, int, char *);
    declare_func(RGSSFinalize, int);
    declare_func(RGSSErrorType, wchar_t *);
    declare_func(RGSSErrorMessage, wchar_t *);
    int bytesRead = 0;
    RGSSInitialize3();
    for (int i = start; i < argc; ++i) {
        FILE *f = fopen(argv[i], "rb");
        bytesRead = fread(buffer, sizeof(char), SIZE - 1, f);
        fclose(f);
        buffer[bytesRead] = '\0';
        if (6 /* nil */ == RGSSEval(buffer)) {
            wchar_t *type = RGSSErrorType(), *msg = RGSSErrorMessage();
            while (*msg++ != '\n') /* strip first two line */;
            wprintf(L"\e[97m%s: (\e[4m%s\e[24m)\e[0m\n", type, ++msg);
        }
    }
    RGSSFinalize();
}
