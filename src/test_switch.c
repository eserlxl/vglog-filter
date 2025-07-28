#include <stdio.h>

int main(int argc, char *argv[]) {
    int option = 1;
    
    switch (option) {
        case 1:
            printf("Option 1\n");
            break;
        case 3:
            printf("Option 3\n");
            break;
        default:
            printf("Default\n");
            break;
    }
    
    return 0;
}
