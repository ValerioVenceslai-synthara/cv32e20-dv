#include <stdio.h>
#include <stdlib.h>
#include "maxpool.h"

// #define MAX_SIZE 4

// Function to perform max pooling on a matrix
void max_pool(int matrix[MAX_SIZE][MAX_SIZE], int size, int pool_size, int output[MAX_SIZE / 2][MAX_SIZE / 2]) {
    int output_size = size / pool_size;
    for (int i = 0; i < output_size; i++) {
        for (int j = 0; j < output_size; j++) {
            int max_val = matrix[i * pool_size][j * pool_size];
            for (int x = 0; x < pool_size; x++) {
                for (int y = 0; y < pool_size; y++) {
                    if (matrix[i * pool_size + x][j * pool_size + y] > max_val) {
                        max_val = matrix[i * pool_size + x][j * pool_size + y];
                    }
                }
            }
            output[i][j] = max_val;
        }
    }
}

int main() {
    // Example input matrix (4x4)
    // int size = 4;
    // int input[MAX_SIZE][MAX_SIZE] = {
    //     {1, 3, 2, 1},
    //     {4, 6, 5, 1},
    //     {3, 7, 1, 3},
    //     {8, 2, 4, 5}
    // };

    // int poolSize = 2;
    int outputSize = size / poolSize;
    // int output[MAX_SIZE / 2][MAX_SIZE / 2];

    // Perform max pooling
    max_pool(input, size, poolSize, output);

    // Print the output matrix
    printf("the result of the maxpool is: \n");
    for (int i = 0; i < outputSize; i++) {
        for (int j = 0; j < outputSize; j++) {
            printf("%d ", output[i][j]);
        }
        printf("\n");
    }

    return 0;
}