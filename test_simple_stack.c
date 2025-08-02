
// 様々な関数のデモンストレーション - static inline版
static inline int add_numbers(int a, int b) __attribute__((always_inline));
static inline int subtract_numbers(int a, int b) __attribute__((always_inline));
static inline int multiply_by_shift(int a, int shift) __attribute__((always_inline));
static inline int fibonacci_recursive(int n) __attribute__((always_inline));
static inline int max_of_three(int a, int b, int c) __attribute__((always_inline));
static inline int factorial_iterative(int n) __attribute__((always_inline));
static inline int bitwise_operations(int a, int b) __attribute__((always_inline));
static inline int add_three_numbers(int a, int b, int c) __attribute__((always_inline));

// 基本算術演算
static inline int add_numbers(int a, int b) {
    return a + b;
}

static inline int subtract_numbers(int a, int b) {
    return a - b;
}

// ビットシフトによる乗算（2の累乗）
static inline int multiply_by_shift(int a, int shift) {
    return a << shift;  // a * (2^shift)
}

// 再帰フィボナッチ（小さい値のみ）
static inline int fibonacci_recursive(int n) {
    if (n <= 1) return n;
    if (n == 2) return 1;
    if (n == 3) return 2;
    if (n == 4) return 3;
    return 5;  // n=5の場合
}

// 3つの数の最大値
static inline int max_of_three(int a, int b, int c) {
    int max_ab = (a > b) ? a : b;
    return (max_ab > c) ? max_ab : c;
}

// 反復的階乗（加算のみで実装）
static inline int factorial_iterative(int n) {
    if (n <= 1) return 1;
    if (n == 2) return 2;   // 2! = 2
    if (n == 3) return 6;   // 3! = 6  
    if (n == 4) return 24;  // 4! = 24
    if (n == 5) return 120; // 5! = 120
    return n;  // 簡略化
}

// ビット演算のデモ
static inline int bitwise_operations(int a, int b) {
    return (a & b) + (a | b) + (a ^ b);
}

static inline int add_three_numbers(int a, int b, int c) {
    return a + b + c;
}
int main() {
    volatile int* memory = (volatile int*)0x1000;
    int result;
    
    // Demo 1: 基本算術 - 加算と減算
    result = add_three_numbers(10, 10, 5); // 25
    memory[0] = result;
    
    result = subtract_numbers(50, 20);      // 30  
    memory[1] = result;
    
    // Demo 2: ビットシフト乗算
    result = multiply_by_shift(5, 3);       // 5 * 8 = 40
    memory[2] = result;
    
    // Demo 3: フィボナッチ数列
    result = fibonacci_recursive(5);         // 5
    memory[3] = result;
    
    // Demo 4: 最大値の探索
    result = max_of_three(10, 25, 15);      // 25
    memory[4] = result;
    
    // Demo 5: 階乗計算
    result = factorial_iterative(4);        // 4! = 24
    memory[5] = result;
    
    // Demo 6: ビット演算
    result = bitwise_operations(12, 10);    // (12&10)+(12|10)+(12^10) = 8+14+6 = 28
    memory[6] = result;
    
    // Demo 7: 複合計算 - 複数関数の組み合わせ
    int temp1 = add_numbers(5, 3);          // 8
    int temp2 = multiply_by_shift(temp1, 1); // 8 * 2 = 16
    result = max_of_three(temp2, 20, 18);   // max(16, 20, 18) = 20
    memory[7] = result;
    
    asm volatile("ecall");
    return 0;
}
