#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    int verbose = 0;
    int help = 0;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--verbose") == 0) {
            verbose = 1;
        } else if (strcmp(argv[i], "--help") == 0) {
            help = 1;
        } else if (strcmp(argv[i], "--baz") == 0) {
            // This is a new option that should trigger minor version bump
            printf("New foo option detected\n");
        }
    }
    
    if (help) {
        printf("Usage: %s [--verbose] [--help] [--baz]\n", argv[0]);
        return 0;
    }
    
    if (verbose) {
        printf("Verbose mode enabled\n");
    }
    
    return 0;
} 