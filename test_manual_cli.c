#include <stdio.h>
#include <string.h>

int main(int argc, char *argv[]) {
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            printf("Help message\n");
            return 0;
        }
        if (strcmp(argv[i], "--version") == 0) {
            printf("Version 1.0.0\n");
            return 0;
        }
        if (strcmp(argv[i], "--verbose") == 0) {
            printf("Verbose mode\n");
            return 0;
        }
    }
    return 1;
}
