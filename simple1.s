_start:
    li      a2, 4       # Inner loop limit
    li      a3, 0       # Outer loop start
    li      a4, 0x0800  # Store write address

1:  li      a0, 0       # Inner loop start

2:  addi    a0, a0, 1   # Inner loop increase
    blt     a0, a2, 2b  # Inner loop jump

    addi    a3, a3, 1   # Outer loop increase
    sw      a3, 0(a4)   # Store outer count at address
    j       1b          # Outer loop jump
