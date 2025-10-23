.data
pass_msg: .asciz "Test Passed\n"
fail_msg: .asciz "Test Failed\n"

.text
.globl bf16_sqrt

.globl main
main:
    addi sp, sp, -4
    sw ra, 0(sp)
    
    # Test Case 1 : sqrt(4) = 2
    li a0, 0x4080
    jal bf16_sqrt
    li t1, 0x4000 # Correct answer
    beq a0, t1, test1_pass
    la a0, fail_msg
    li a7, 4
    ecall
    j test2
test1_pass:
    la a0, pass_msg
    li a7, 4
    ecall
test2:
    # Test Case 2 : sqrt(9) = 3
    li a0, 0x4110
    jal bf16_sqrt
    li t1, 0x4040
    beq a0, t1, test2_pass
    la a0, fail_msg
    li a7, 4
    ecall
    j test3
test2_pass:
    la a0, pass_msg
    li a7, 4
    ecall
test3:
    # Test Case 3 : sqrt(16) = 4
    li a0, 0x4180
    jal bf16_sqrt
    li t1, 0x4080
    beq a0, t1, test3_pass
    la a0, fail_msg
    li a7, 4
    ecall
    j test4
test3_pass:
    la a0, pass_msg
    li a7, 4
    ecall
test4:
    # Test Case 4 : sqrt(-4) = Nan
    li a0, 0xC080
    jal bf16_sqrt
    li t1, 0x7FC0
    beq a0, t1, test4_pass
    la a0, fail_msg
    li a7, 4
    ecall
    j test_end
test4_pass:
    la a0, pass_msg
    li a7, 4
    ecall
    
test_end:
    lw ra, 0(sp)
    addi sp, sp, 4
    li a7, 10
    ecall

bf16_sqrt:
    addi sp, sp, -32
    sw ra, 28(sp)
    sw s0, 24(sp)
    sw s1, 20(sp)
    sw s2, 16(sp)
    sw s3, 12(sp)
    sw s4, 8(sp)
    sw s5, 4(sp)
    sw s6, 0(sp)
    srli t0, a0, 15            # Shift right 15 
    andi t0, t0, 1             # Extract sign bit by and operation with 1
    srli t1, a0, 7             # Shift right 7
    andi t1, t1, 0xFF          # Extract exponent by and operation with 0xFF (8 bits)
    andi t2, a0, 0x7F          # And operation with 0x7F to extract mantissa
    li t3, 0xFF
    bne t1, t3, check_zero     # Branch if exp is not equal to 0xFF
    bnez t2, return_a          # Branch if mantissa is not equal to zero
    bnez t0, return_nan        # Branch if sign bit is not equal to zero
    j return_a                 # Return the value of a (input)
check_zero: # First special case
    or t3, t1, t2              # 
    bnez t3, check_negative
    j return_zero
check_negative: # Second special case
    bnez t0, return_nan
    bnez t1, compute_sqrt
    j return_zero
compute_sqrt:
    addi s0, t1, -127
    ori s1, t2, 0x80
    andi t3, s0, 1
    beqz t3, even_exp
    slli s1, s1, 1
    addi t4, s0, -1
    srai t4, t4, 1
    addi s2, t4, 127
    j binary_search
even_exp:
    srai t4, s0, 1
    addi s2, t4, 127
binary_search:
    li s3, 90
    li s4, 256
    li s5, 128
search_loop:
    bgt s3, s4, search_done
    add t3, s3, s4
    srli t3, t3, 1
    mv a1, t3
    mv a2, t3
    jal multiply
    mv t4, a0
    srli t4, t4, 7
    bgt t4, s1, search_high
    mv s5, t3
    addi s3, t3, 1
    j search_loop
search_high:
    addi s4, t3, -1
    j search_loop
search_done:
    li t3, 256
    blt s5, t3, check_low
    srli s5, s5, 1
    addi s2, s2, 1
    j extract_mant
check_low:
    li t3, 128
    bge s5, t3, extract_mant
norm_loop:
    li t3, 128
    bge s5, t3, extract_mant
    li t3, 1
    ble s2, t3, extract_mant
    slli s5, s5, 1
    addi s2, s2, -1
    j norm_loop
extract_mant:
    andi s6, s5, 0x7F
    li t3, 0xFF
    bge s2, t3, return_inf
    blez s2, return_zero
    andi t3, s2, 0xFF
    slli t3, t3, 7
    or a0, t3, s6
    j cleanup
return_zero:
    li a0, 0
    j cleanup
return_nan:
    li a0, 0x7FC0
    j cleanup
return_inf:
    li a0, 0x7F80
    j cleanup
return_a:
cleanup:
    lw s6, 0(sp)
    lw s5, 4(sp)
    lw s4, 8(sp)
    lw s3, 12(sp)
    lw s2, 16(sp)
    lw s1, 20(sp)
    lw s0, 24(sp)
    lw ra, 28(sp)
    addi sp, sp, 32
    ret
multiply:
    li a0, 0
    beqz a2, mult_done
mult_loop:
    andi t0, a2, 1
    beqz t0, mult_skip
    add a0, a0, a1
mult_skip:
    slli a1, a1, 1
    srli a2, a2, 1
    bnez a2, mult_loop
mult_done:
    ret