#include <stdio.h>
#include <stdint.h>
#include "maxpool.h"

// Function to perform max pooling using SIMD

void max_pool(int matrix[MAX_SIZE][MAX_SIZE / 2], int size, int pool_size, int output[MAX_SIZE / pool_size][MAX_SIZE / pool_size]) {
    int output_size = size / pool_size;

    for (int i = 0; i < output_size; i++) {
        for (int j = 0; j < output_size; j++) {
            // int max_val = 0;  // Start with the lowest possible value for an unsigned 16-bit integer
            int first = 1;  // Flag to initialize max_val with the first element
            int max_val = matrix[i * pool_size][j * (pool_size/2)];
            for (int x = 1; x < pool_size; x++) {
                for (int y = 0; y < pool_size / 2; y++) {
                    int current_val = matrix[i * pool_size + x][j * (pool_size / 2) + y];

                    // if (first) {
                        // max_val = current_val;  // Initialize max_val with the first value encountered
                        // first = 0;  // Clear the first flag after the first initialization
                    // } else {
                        int temp;
                        // Inline assembly to perform SIMD max operation using the custom operation cv.max.h
                        __asm__ ("cv.max.h %0, %1, %2"
                                 : "=r" (temp)
                                 : "r" (max_val), "r" (current_val));
                        max_val = temp;  // Update max value based on comparison
                        // hi = max_val >> 16 > current_val >> 16 ? max_val >> 16 : current_val >> 16;
                        // lo = max_val & 0xFFFF > current_val & 0xFFFF ? max_val & 0xFFFF : current_val & 0xFFFF;
                        // max_val = (hi << 16) | lo;
                    // }
                }
            }

            // Further reduce the max value to a single maximum value for the entire pool
            int final_max = (max_val >> 16) > (max_val & 0xFFFF) ? (max_val >> 16) : (max_val & 0xFFFF);

            // Store the max result for the current pooling window as a single max value
            output[i][j] = final_max;  // Note that the output is 32-bit but we store a 16-bit max value
        }
    }
}


void set_csr(int value) {
    // Inline assembly to write to CSR at address 0xa0
    __asm__ volatile (
        "csrw 0xA0, %0"  // Write the value in 'value' to CSR at address 0xA0
        :                 // No output operands
        : "r"(value)     // Input operand: value to write to the CSR
        : "memory"       // Clobbers: Tell the compiler that memory may be affected
    );
}


int main() {
    int output[MAX_SIZE / poolSize][MAX_SIZE / poolSize];

    // Perform max pooling
    set_csr(2);  // Example call to set the CSR to 123

    max_pool(matrix, size, poolSize, output);

    // Print the output matrix
    // printf("Max pool result:\n");
    // for (int i = 0; i < size / poolSize; i++) {
    //     for (int j = 0; j < size / poolSize; j++) {
    //         printf("0x%08X ", output[i][j]);
    //     }
    //     printf("\n");
    // }

    // printf("Done\n");
    return 0;
}
