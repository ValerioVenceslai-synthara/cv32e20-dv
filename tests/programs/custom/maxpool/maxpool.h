#include <stdlib.h>
#define MAX_SIZE 4

int size = 4;
int input[MAX_SIZE][MAX_SIZE] = {
    {1, 3, 2, 1},
    {4, 6, 5, 1},
    {3, 7, 1, 3},
    {8, 2, 4, 5}
};

int poolSize = 2;

int output[MAX_SIZE / 2][MAX_SIZE / 2];