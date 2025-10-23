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
    srli t0, a0, 16
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
bf16_t0_f32:
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