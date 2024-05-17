#include "rand.h"

// Function to generate a pseudo-random number
uint32_t custom_rand() {
    static unsigned int seed = 0; // Initialize the seed with a default value
    seed = (RAND_A * seed + RAND_C) % RAND_M;
    return seed;
}

uint32_t random_num(uint32_t upper_bound, uint32_t lower_bound) {
    uint32_t random_num = random_num32();
    uint32_t num = (random_num  % (upper_bound - lower_bound + 1)) + lower_bound;
    return num;
}

uint32_t random_num32() {
    return (uint32_t) custom_rand() ;
}
