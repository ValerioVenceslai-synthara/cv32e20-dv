#include <stdint.h>

// Define constants for the LCG algorithm
#define RAND_A 1103515245
#define RAND_C 12345
#define RAND_M 2147483648 // 2^31

// Function to generate a pseudo-random number
uint32_t custom_rand();

uint32_t random_num(uint32_t upper_bound, uint32_t lower_bound);

uint32_t random_num32();
