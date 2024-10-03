import random
import argparse

def generate_random_matrix(size, seed):
    """Generates a size x size random matrix with two 16-bit integers per 32-bit word."""
    random.seed(seed)
    matrix = []
    for _ in range(size):
        row = []
        for _ in range(size // 2):  # Create matrix with two halfwords per 32-bit word
            halfword1 = random.randint(0, 100)
            halfword2 = random.randint(0, 100)
            # Pack two 16-bit halfwords into one 32-bit word
            word = (halfword1 << 16) | halfword2
            row.append(word)
        matrix.append(row)
    return matrix

def write_matrix_to_header(args, matrix, filename):
    """Writes the matrix to a .h file in the specified format."""
    with open(filename, 'w') as file:
        file.write("#include <stdint.h>\n")
        file.write(f"#define MAX_SIZE {args.size}\n\n")
        
        file.write(f"int size = {len(matrix)};\n")
        file.write("uint32_t matrix[MAX_SIZE][MAX_SIZE / 2] = {\n")  # Each word contains two halfwords

        for row in matrix:
            file.write("    { " + ", ".join(map(str, row)) + " },\n")

        file.write("};\n\n")
        
        file.write(f"int poolSize = {args.poolSize};")
        
if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a random matrix and write it to a .h file.")
    parser.add_argument("size", type=int, help="Size of the square matrix to generate.")
    parser.add_argument("poolSize", type=int, help="Size of the pooling window.")
    args = parser.parse_args()
    seed = random.randint(1, 2147483647)  # Generate a random seed
    matrix = generate_random_matrix(args.size, seed)
    write_matrix_to_header(args, matrix, "maxpool.h")
    print(f"Random {args.size}x{args.size} matrix written to maxpool.h")
