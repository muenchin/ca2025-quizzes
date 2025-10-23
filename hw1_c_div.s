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
    li a0, 0x4040        # 3
    li a1, 0x4000          # 2
    jal bf16_div
    
    li t1, 0x3FC0       # correct answer = 3 / 2 = 1.5
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
    li a0, 0x3F80            # 1
    li a1, 0x3F00            # 0.5
    
    jal bf16_div
    
    li t1, 0x4000            # correct answer = 1 / 0.5 = 2
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
    li a0, 0x4080            # 4
    li a1, 0xC040            # -3
    jal bf16_div    
    li t1, 0xBFAA            # correct answer = 4 / (-3) = -1.333... 
    beq a0, t1, test3_pass
    la a0, fail_msg
    li a7, 4
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
    
.globl bf16_isnan
bf16_isnan:
    li t0, 0x7F80
    and t1, a0, t0
    bne t1, t0, isnan_false
    li t2, 0x007F
    and t3, a0, t2
    snez a0, t3
    ret
isnan_false:
    li a0, 0
    ret
bf16_isinf:
    li t0, 0x7F80
    and t1, a0, t0
    bne t1, t0, isinf_false
    li t2, 0x007F
    and t3, a0, t2
    seqz a0, t3
    ret
isinf_false:
    li a0, 0
    ret
bf16_iszero:
    li t0, 0x7FFF
    and t1, a0, t0
    seqz a0, t1
    ret
    
.globl f32_to_bf16    
f32_to_bf16:
    addi sp, sp, -4
    sw s0, 0(sp)
    mv s0, a0
    srli t0, s0, 23
    andi t0, t0, 0xFF
    li t1, 0xFF
    bne t0, t1, unspecial
    srli a0, s0, 16
    li t0, 0xFFFF
    and a0, a0, t0
    j f32_to_bf16_done
unspecial:
    srli t0, s0, 16
    andi t0, t0, 1
    li t1, 0x7FFF
    add t0, t0, t1
    add s0, s0, t0
    srli a0, s0, 16
f32_to_bf16_done:
    lw s0, 0(sp)
    addi sp, sp, 4
    ret
    
.globl bf16_to_f32       
bf16_to_f32:
    slli a0, a0, 16
    ret
.globl BF16_NAN
BF16_NAN:
    li a0, 0x7FC0
    ret
.globl BF16_ZERO
BF16_ZERO:
    li a0, 0x0000
    ret
    
.globl bf16_div
bf16_div:
    addi sp, sp, -16
    sw s0, 0(sp)
    sw s1, 4(sp)
    sw s2, 8(sp)
    sw s3, 12(sp)
    srli t0, a0, 15            # a.bits >> 15
    andi t0, t0, 1             # & 1             # t0 = sign_a
    srli t1, a1, 15            # b.bits >> 15
    andi t1, t1, 1             # & 1             # t1 = sign_b
    srli t2, a0, 7             # a.bits >> 7              
    andi t2, t2, 0xFF          # & 0xFF          # t2 = exp_a
    srli t3, a1, 7             # b.bits >> 7
    andi t3, t3, 0xFF          # & 0xFF          # t3 = exp_b
    andi t4, a0, 0x7F                            # t4 = mant_a
    andi t5, a1, 0x7F                            # t5 = mant_b
    
    xor s0, t0, t1             # s0 = result_sign = sign_a ^ sign_b
    li t6, 0xFF                # t6 is for temporal usage
    bne t3, t6, check_zero     # branch if(exp_b != 0xFF)
    beqz t5, check_inf         # branch if mant = 0 => return b
    mv a0, a1                  # return b
    j recover
check_inf:
    li t6, 0xFF                
    bne t2, t6, result_sign_1
    bnez t4, result_sign_1
    li a0, 0x7FC0              # return Nan
    j recover
result_sign_1:
    slli a0, s0, 15
    j recover    
check_zero:
    bnez t3, check_2_inf
    bnez t5, check_2_inf
    bnez t2, result_sign_2
    bnez t4, result_sign_2
    li a0, 0x7FC0            # return Nan
    j recover
    
result_sign_2:
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j recover
check_2_inf:
    li t6, 0xFF
    bne t2, t6, check_div_zero
    beqz t4, result_3
    mv a0, a0                # return a
    j recover
result_3:
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j recover
check_div_zero:
    bnez t2, norm
    bnez t4, norm
    slli a0, s0, 15
    j recover
norm:
    beqz t2, norm_b
    ori t4, t4, 0x80
norm_b:
    beqz t3, norm_end
    ori t5, t5, 0x80
norm_end:
    slli s1, t4, 15        # s1 : dividend = mant_a << 15
    mv s2, t5              # s2 : divisor = mant_b
    li s3, 0               # s3 : quotient = 0
    
    li t6, 0               # t6 : i=0
div_loop:
    li a2, 16              # a3 = 16
    bge t6, a2, end_div_loop             # branch if i >= 16
    slli s3, s3, 1                       # quotient <<= 1
    li a3, 15
    sub a3, a3, t6                    # a2 = 15 - i
    sll a4, s2, a3                    # a3 = divisor << (15-i)
    bltu s1, a4, skip_sub             # branch if dividend is less than 
    sub s1, s1, a4                    # dividend -= (divisor << (15-i))
    ori s3, s3, 1                     # quotient |= 1
skip_sub:
    addi t6, t6, 1                    # i++
    j div_loop
end_div_loop:                    
    sub a2, t2, t3                   # a2 = exp_a - exp_b     
    addi a2, a2, 127                 # a2 = result_exp = exp_a - exp_b + BF16_EXP_BIAS
    bnez t2, res_b                   # branch if exp_a != 0
    addi a2, a2, -1
res_b:
    bnez t3, q_check                 # branch if exp_b != 0
    addi a2, a2, 1
q_check:
    li t6, 0x8000
    and a4, s3, t6                        # quotient & 0x8000
    beqz a4, q_else
    srli s3, s3, 8
    j check_overflow
q_else:
q_loop:
    li t6, 0x8000
    and a4, s3, t6                # quotient & 0x8000
    bnez a4, q_loop_done
    li t6, 1
    ble a2, t6, q_loop_done
    slli s3, s3, 1
    addi a2, a2, -1
    j q_loop
q_loop_done:
    srli s3, s3, 8
check_overflow:
    andi s3, s3, 0x7F    
    li t6, 0xFF
    bge a2, t6, overflow
    j check_un
overflow:
    slli a0, s0, 15
    li t6, 0x7F80
    or a0, a0, t6
    j recover
check_un:
    bgt a2, x0, final_result
    slli a0, s0, 15
    j recover
final_result:
    slli a0, s0, 15
    andi a2, a2, 0xFF
    slli a2, a2, 7
    or a0, a0, a2
    andi s3, s3, 0x7F
    or a0, a0, s3
recover:
    lw s0, 0(sp)
    lw s1, 4(sp)
    lw s2, 8(sp)
    lw s3, 12(sp)
    addi sp, sp, 16
    ret    