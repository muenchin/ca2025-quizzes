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
    li a0, 0x4040            # 3
    li a1, 0x4000            # 2
    jal bf16_sub
    li t1, 0x3F80            # correct answer = 3 - 2 = 1
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
    jal bf16_sub
    li t1, 0x3F00            # correct answer = 1 - 0.5 = 0.5
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
    jal bf16_sub
    li t1, 0x40E0            # correct answer = 4 + (-3) = 7 
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
    
.globl bf16_sub
bf16_sub:
    li t0, 0x8000
    xor a1, a1, t0
    j bf16_add
    
.globl bf16_add
bf16_add:
    srli t0, a0, 15            # a.bits >> 15
   # andi t0, t0, 1             # & 1 , but we don't need this line because after srli 15 bits, the msb is already bit 15
    srli t1, a1, 15            # b.bits >> 15
   # andi t1, t1, 1             # & 1 , omit this line, same reason as above
    srli t2, a0, 7             # a.bits >> 7              
    andi t2, t2, 0xFF          # & 0xFF
    srli t3, a1, 7             # b.bits >> 7
    andi t3, t3, 0xFF          # & 0xFF
    andi t4, a0, 0x7F
    andi t5, a1, 0x7F
    
    li t6, 0xFF
    # beq t2, t6, exp_a_checkall
    # j check_exp_b , simplify these two lines into bne
    bne t2, t6, check_exp_b

exp_a_checkall:
    bnez t4, ret_a
    bne t3, t6, ret_a
    bnez t5, return_b1
    bne t0, t1, return_nan
return_b1:
    mv a0, a1
    ret
return_nan:
    li a0, 0x7FC0
ret_a:
    ret
check_exp_b:
    beq t3, t6, return_b2
    j check_0_a
return_b2:
    mv a0, a1
    ret
check_0_a:
    bnez t2, check_0_b
    bnez t4, check_0_b
    mv a0, a1
    ret
check_0_b:
    bnez t3, norm_a
    bnez t5, norm_a
    ret
norm_a:
    beqz t2, norm_b
    ori t4, t4, 0x80
norm_b:
    beqz t3, end_check1
    ori t5, t5, 0x80
end_check1:
    addi sp, sp, -20
    sw s0, 16(sp)            # for exp_diff
    sw s1, 12(sp)             # for result_sign
    sw s2, 8(sp)             # for result_exp
    sw s3, 4(sp)             # for result_mant
    sw s4, 0(sp)
    sub s0, t2, t3           # exp_diff = exp_a - exp_b
    blez s0, diff_neg        # branch if exp_diff <= 0
    mv s2, t2                # result_exp = exp_a
    
    li t6, 8
    bgt s0, t6, return_a
    srl t5, t5, s0
    j exp_done
diff_neg:
    bgez s0, diff_else
    mv s2, t3
    li t6, -8
   # blt s0, t6, return_b3
   # neg s4, s0
    #srl t4, t4, s4
    #j exp_done, substitute blf & j with bge
    bge s0, t6, shift_a
shift_a:
    neg s4, s0
    srl t4, t4, s4
    j exp_done
diff_else:
    mv s2, t2
    j exp_done
return_a:
    lw s0, 16(sp)
    lw s1, 12(sp)
    lw s2, 8(sp)
    lw s3, 4(sp)
    lw s4, 0(sp)
    addi sp, sp, 20
    ret
return_b3:
    lw s0, 16(sp)
    lw s1, 12(sp)
    lw s2, 8(sp)
    lw s3, 4(sp)
    lw s4, 0(sp)
    addi sp, sp, 20
    mv a0, a1
    ret
exp_done:
    bne t0, t1, diff_sign        # branch if sign_a != sign_b
same_sign:
    mv s1, t0
    add s3, t4, t5
    andi t6, s3, 0x100
    beqz t6, norm_end
    srli s3, s3, 1
    addi s2, s2, 1
    li t6, 0xFF
    bge s2, t6, overflow_inf
    j norm_end
overflow_inf:
    lw s0, 16(sp)
    lw s1, 12(sp)
    lw s2, 8(sp)
    lw s3, 4(sp)
    lw s4, 0(sp)
    addi sp, sp, 20
    
    slli a0, s1, 15
    li t6, 0x7F80
    or a0, a0, t6
    ret

diff_sign:
    bge t4, t5, manta_>_mantb
    mv s1, t1
    sub s3, t5, t4
    j mant_result

manta_>_mantb:
    mv s1, t0
    sub s3, t4, t5
mant_result:
    beqz s3, return_zero
norm_loop:
    andi t6, s3, 0x80
    bnez t6, norm_end
    slli s3, s3, 1
    addi s2, s2, -1
    blez s2, return_zero
    j norm_loop
norm_end:   
    
    slli a0, s1, 15
    andi t0, s2, 0xFF
    slli t0, t0, 7
    or a0, a0, t0
    andi t0, s3, 0x7F
    or a0, a0, t0
    
    lw s0, 16(sp)
    lw s1, 12(sp)
    lw s2, 8(sp)
    lw s3, 4(sp)
    lw s4, 0(sp)
    addi sp, sp, 20
    ret
return_zero:
    lw s0, 16(sp)
    lw s1, 12(sp)
    lw s2, 8(sp)
    lw s3, 4(sp)
    lw s4, 0(sp)
    addi sp, sp, 20 
    li a0, 0x0000
    ret