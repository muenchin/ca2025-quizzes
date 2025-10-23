.data
newline: .string "\n"
pass_msg: .asciz "Test Passed\n"
fail_msg: .asciz "Test Failed\n"

.text
.globl main
main:
    addi sp, sp, -4
    sw ra, 0(sp)
    # Test Case 1 : 
    li a0, 0x3F80            # 1
    li a1, 0x4000            # 2
    jal bf16_mul
    li t1, 0x4000            # correct answer
    beq a0, t1, test1_pass
    la t0, fail_msg   
    li a7, 4
    ecall
    j test2
test1_pass:
    la a0, pass_msg
    li a7, 4
    ecall
test2:
    li a0, 0x3F00
    li a1, 0x3F00
    jal bf16_mul
    li t1, 0x3E80   # �w��
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
    li a0, 0x4040
    li a1, 0x4080
    jal bf16_mul
    li t1, 0x4140
    beq a0, t1, test3_pass
    la a0, fail_msg
    ecall
    j test_end
test3_pass:
    la a0, pass_msg
    li a7, 4
    ecall

test_end:
    lw ra, 0(sp)
    addi sp, sp, 4    
    li a7, 10
    ecall
    
.globl bf16_mul    
bf16_mul:
    addi sp, sp, -16
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw ra, 12(sp)
    srli t0, a0, 15            # a.bits >> 15
    andi t0, t0, 1             # t0 = sign_a
    srli t1, a1, 15            # b.bits >> 15
    andi t1, t1, 1             # t1 = sign_b
    srli t2, a0, 7             # a.bits >> 7              
    andi t2, t2, 0xFF          # t2 = exp_a
    srli t3, a1, 7             # b.bits >> 7
    andi t3, t3, 0xFF          # t3 = exp_b
    andi t4, a0, 0x7F          # t4 = mant_a
    andi t5, a1, 0x7F          # t5 = mant_b
    xor s0, t0, t1             # s0 = result_sign
    li t6, 0xFF
    bne t2, t6, check_b_exp
    bnez t4, return_a
    bnez t3, result_1
    bnez t5, result_1
    j return_nan
result_1:
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j quit
check_b_exp:
    li t6, 0xFF
    bne t3, t6, check_0
    bnez t5, return_b
    bnez t2, result_2
    bnez t4, result_2
    j return_nan
result_2:
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j quit
check_0:
    bnez t2, a_not_zero
    bnez t4, a_not_zero
    j return_0
a_not_zero:
    bnez t3, norm_mant
    bnez t5, norm_mant
return_0:
    slli a0, s0, 15
    j quit
norm_mant:
    li s1, 0                        # s1 : exp_adjust = 0
    bnez t2, norm_a_else            # if(!exp_a)
norm_loop_a:
    andi t6, t4, 0x80
    bnez t6, norm_loop_a_done
    slli t4, t4, 1
    addi s1, s1, -1
    j norm_loop_a
norm_loop_a_done:
    li t2, 1
    j check_exp_b_norm
norm_a_else:
    ori t4, t4, 0x80
check_exp_b_norm:
    bnez t3, else_norm_b
norm_loop_b:
    andi t6, t5, 0x80
    bnez t6, norm_b_done
    slli t5, t5, 1
    addi s1, s1, -1
    j norm_loop_b
norm_b_done:
    li t3, 1
    j mul_mant 
else_norm_b:
    ori t5, t5, 0x80
mul_mant:
    mul s2, t4, t5           # s2 = result_mant
    add t6, t2, t3
    addi t6, t6, -127
    add t6, t6, s1
    mv s1, t6                # s1 = result_exp
    li t6, 0x8000
    and t6, s2, t6
    beqz t6, mult_else
    srli s2, s2, 8
    andi s2, s2, 0x7F
    addi s1, s1, 1
    j check_exp_overflow
mult_else:
    srli s2, s2, 7
    andi s2, s2, 0x7F
check_exp_overflow:
    li t6, 0xFF
    blt s1, t6, underflow_check    
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j quit
underflow_check:
    bgt s1, zero, final
    li t6, -6
    blt s1, t6, return_0_udflow
    li t6, 1
    sub t6, t6, s1
    srl s2, s2, t6
    li s1, 0
    j final
return_0_udflow:
    slli a0, s0, 15
    j quit
final:
    slli a0, s0, 15
    andi s1, s1, 0xFF
    slli s1, s1, 7
    andi s2, s2, 0x7F
    or a0, a0, s1
    or a0, a0, s2
    j quit
return_a:
    j quit
return_b:
    mv a0, a1
    j quit
return_nan:
    li a0, 0x7FC0
    j quit
quit:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret