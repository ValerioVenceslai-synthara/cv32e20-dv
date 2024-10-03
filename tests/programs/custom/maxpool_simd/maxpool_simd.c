#include <stdio.h>
#include <stdint.h>
#include "maxpool.h"

// Function to perform max pooling using SIMD
void max_pool(int matrix[MAX_SIZE][MAX_SIZE / 2], int size, int pool_size, int output[MAX_SIZE / pool_size][MAX_SIZE / (2 * pool_size)]) {
    int output_size = size / pool_size;

    for (int i = 0; i < output_size; i++) {
        for (int j = 0; j < output_size / 2; j++) {  // Iterate over 32-bit words, which hold two halfwords
            int max_val = matrix[i * pool_size][j];  // Initialize max value

            for (int x = 0; x < pool_size; x++) {
                for (int y = 0; y < pool_size / 2; y++) {  // Process two halfwords at a time
                    int current_val = matrix[i * pool_size + x][j * pool_size + y];
                    int temp;
                    int lo;
                    int hi;

                    // Inline assembly to perform SIMD max operation on two halfwords at a time
                    reg_t lo = ((sreg_t(RS1) & 0x0000FFFF) > (sreg_t(RS2) & 0x0000FFFF) ? (RS1 & 0x0000FFFF) : (RS2 & 0x0000FFFF));
                    reg_t hi = ((sreg_t(RS1) & 0xFFFF0000) > (sreg_t(RS2) & 0xFFFF0000) ? (RS1 & 0xFFFF0000) : (RS2 & 0xFFFF0000));
                    WRITE_RD(sext_xlen(lo | hi))

                    max_val = temp;  // Update the max value
                }
            }

            output[i][j] = max_val;  // Store the max result for the current pooling window
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
    int output[MAX_SIZE / poolSize][MAX_SIZE / (2 * poolSize)];

    // Perform max pooling
    set_csr(2);  // Example call to set the CSR to 123

    max_pool(matrix, size, poolSize, output);

    // Print the output matrix
    printf("Max pool result:\n");
    for (int i = 0; i < size / poolSize; i++) {
        for (int j = 0; j < size / (2 * poolSize); j++) {
            printf("0x%08X ", output[i][j]);
        }
        printf("\n");
    }

    printf("Done\n");
    return 0;
}
