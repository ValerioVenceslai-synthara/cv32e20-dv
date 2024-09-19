#include <stdio.h>
#include <stdlib.h>

// Function to perform 2D max pooling
void maxPooling(int input[4][4], int output[2][2], int inputSize, int poolSize, int stride) {
    int outputSize = inputSize / poolSize;

    for (int i = 0; i < inputSize; i += stride) {
        for (int j = 0; j < inputSize; j += stride) {
            // Max pool a 2x2 block
            int maxVal = input[i][j];  // Start with the top-left element of the 2x2 block
            for (int m = 0; m < poolSize; ++m) {
                for (int n = 0; n < poolSize; ++n) {
                    if (input[i + m][j + n] > maxVal) {
                        maxVal = input[i + m][j + n];
                    }
                }
            }
            // Place the max value in the output matrix
            output[i / stride][j / stride] = maxVal;
        }
    }
}

int main() {
    // Example input matrix (4x4)
    int input[4][4] = {
        {1, 3, 2, 1},
        {4, 6, 5, 1},
        {3, 7, 1, 3},
        {8, 2, 4, 5}
    };

    int output[2][2];  // Output matrix for max pooling

    int poolSize = 2;
    int stride = 2;

    // Perform max pooling
    maxPooling(input, output, 4, poolSize, stride);

    // Print the output matrix
    printf("the result of the maxpool is: \n");
    for (int i = 0; i < 2; ++i) {
        for (int j = 0; j < 2; ++j) {
            printf("%d ", output[i][j]);
        }
        printf("\n");
    }

    return 0;
}
