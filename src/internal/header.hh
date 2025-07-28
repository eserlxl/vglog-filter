#ifndef INTERNAL_HEADER_HH
#define INTERNAL_HEADER_HH

// Function prototype that could be removed to test API breaking detection
int process_data(const char* input, int length);

// Another function that could be removed
void cleanup_resources(void);

// This function will be removed to test API breaking detection

#endif // INTERNAL_HEADER_HH 