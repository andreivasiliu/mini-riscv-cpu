inline int char_to_segments(char c) {
    switch (c) {
        case 'h': return 0b01110110;
        case 'e': return 0b01111001;
        case 'l': return 0b00111000;
        case 'o': return 0b00111111;
    }
}

inline int hello_word(int index) {
    switch (index) {
        case 0: return 'h';
        case 1: return 'e';
        case 2: return 'l';
        case 3: return 'l';
        case 4: return 'o';
    }
}

void _start() {
    volatile int *addr = (volatile int *) 0x30000;
    int value = 0;

    while (1) {
        *addr = 0b01110110000000000000000000000000;
        *addr = 0;
        *addr = 0b011110010000000000000000;
        *addr = 0;
        *addr = 0b0011100000000000;
        *addr = 0;
        *addr = 0b0011100000000000;
        *addr = 0;
        *addr = 0b00111111;
        *addr = 0;

        for (int i = 0; i < 4; i++) {
            value += 1;
            *addr = value;
        }

        *addr = 0;
    }
}

