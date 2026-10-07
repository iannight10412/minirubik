.text
.globl _start
_start:
    jal ra, main
    li a7, 10
    ecall

# void quarter_turn(const state_t *state, state_t *result, uint8_t face)
quarter_turn:
    slli t0, a2, 3
    sub  t0, t0, a2          # t0 = face * 7
    la   t1, source
    add  t1, t1, t0          # &source[face][0]
    la   t2, twist
    add  t2, t2, t0          # &twist[face][0]
    li   t3, 0               # i = 0
    li   t6, 7
    li   a6, 3
qt_loop:
    lbu  t4, 0(t1)           # from = source[face][i]
    add  t5, a0, t4          # &state->p[from]
    lbu  a3, 0(t5)           # state->p[from]
    lbu  a4, 7(t5)           # state->o[from]
    lbu  a5, 0(t2)           # twist[face][i]
    add  a4, a4, a5          # sum = state->o[from] + twist[face][i]
    bltu a4, a6, qt_skip
    addi a4, a4, -3
qt_skip:
    add  t5, a1, t3          # &result->p[i]
    sb   a3, 0(t5)           # result->p[i] = state->p[from]
    sb   a4, 7(t5)           # result->o[i] = sum
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, 1
    bne  t3, t6, qt_loop
    ret

# uint16_t rank_perm(const state_t *state)
rank_perm:
    li   t0, 0               # p = 0
    li   t1, 0               # i = 0
    li   t6, 6
    li   a6, 7
rp_outer:
    li   t2, 0               # smaller = 0
    add  t3, a0, t1
    lbu  t3, 0(t3)           # pi = state->p[i]
    addi t4, t1, 1           # j = i + 1
rp_inner:
    add  t5, a0, t4
    lbu  t5, 0(t5)           # state->p[j]
    bgeu t5, t3, rp_not_smaller
    addi t2, t2, 1
rp_not_smaller:
    addi t4, t4, 1
    bltu t4, a6, rp_inner
    # p = p * (7 - i) + smaller (純加減法迴圈，無 __mulsi3)
    sub  t4, a6, t1          # k = 7 - i
    li   t5, 0               # next_p = 0
rp_mul:
    add  t5, t5, t0
    addi t4, t4, -1
    bnez t4, rp_mul
    add  t0, t5, t2
    addi t1, t1, 1
    bne  t1, t6, rp_outer
    mv   a0, t0
    ret

# uint16_t rank_ori(const state_t *state)
rank_ori:
    li   t0, 0               # o = 0
    li   t1, 0               # i = 0
    li   t6, 6
ro_loop:
    slli t2, t0, 1
    add  t0, t2, t0          # o * 3
    add  t3, a0, t1
    lbu  t3, 7(t3)           # state->o[i]
    add  t0, t0, t3
    addi t1, t1, 1
    bne  t1, t6, ro_loop
    mv   a0, t0
    ret

# void unrank_perm(uint16_t p, state_t *state)
unrank_perm:
    addi sp, sp, -16
    li   t0, 0
    li   t6, 7
up_init:
    add  t1, sp, t0
    sb   t0, 0(t1)           # available[i] = i
    addi t0, t0, 1
    bne  t0, t6, up_init
    la   t2, fact
    li   t0, 0               # i = 0
up_outer:
    lhu  t3, 0(t2)           # f = fact[i]
    li   t4, 0               # q = 0
up_div:
    bltu a0, t3, up_div_done
    sub  a0, a0, t3
    addi t4, t4, 1
    j    up_div
up_div_done:
    add  t1, sp, t4
    lbu  t5, 0(t1)           # available[q]
    add  a2, a1, t0
    sb   t5, 0(a2)           # state->p[i] = available[q]
    sb   zero, 7(a2)         # state->o[i] = 0
    li   a3, 6
    sub  a3, a3, t0          # 6 - i
    mv   t5, t4              # j = q
up_shift:
    bgeu t5, a3, up_shift_done
    add  t1, sp, t5
    lbu  a4, 1(t1)
    sb   a4, 0(t1)
    addi t5, t5, 1
    j    up_shift
up_shift_done:
    addi t2, t2, 2
    addi t0, t0, 1
    bne  t0, t6, up_outer
    addi sp, sp, 16
    ret

# void unrank_ori(uint16_t o, state_t *state)
unrank_ori:
    la   t2, pow3
    li   t0, 0               # i = 0
    li   t1, 0               # sum = 0
    li   t6, 6
    li   a6, 3
uo_outer:
    sb   zero, 0(a1)         # 清空 p[i]
    lhu  t3, 0(t2)           # p3 = pow3[i]
    li   t4, 0               # d = 0
uo_div:
    bltu a0, t3, uo_div_done
    sub  a0, a0, t3
    addi t4, t4, 1
    j    uo_div
uo_div_done:
    sb   t4, 7(a1)           # state->o[i] = d
    add  t1, t1, t4
    bltu t1, a6, uo_skip
    addi t1, t1, -3
uo_skip:
    addi a1, a1, 1
    addi t2, t2, 2
    addi t0, t0, 1
    bne  t0, t6, uo_outer
    sb   zero, 0(a1)
    beqz t1, uo_zero
    sub  t1, a6, t1
uo_zero:
    sb   t1, 7(a1)           # state->o[6] = (3 - sum) % 3
    ret

# int valid(const state_t *state)
valid:
    li   t0, 0               # sum = 0
    li   t1, 0               # i = 0
    li   t6, 7
    li   a6, 3
val_outer:
    add  t2, a0, t1
    lbu  t3, 0(t2)           # p[i]
    lbu  t4, 7(t2)           # o[i]
    bgeu t3, t6, val_fail
    bgeu t4, a6, val_fail
    li   t5, 0               # j = 0
val_inner:
    beq  t5, t1, val_inner_done
    add  a2, a0, t5
    lbu  a2, 0(a2)
    beq  a2, t3, val_fail
    addi t5, t5, 1
    j    val_inner
val_inner_done:
    add  t0, t0, t4
    bltu t0, a6, val_skip
    addi t0, t0, -3
val_skip:
    addi t1, t1, 1
    bne  t1, t6, val_outer
    seqz a0, t0
    ret
val_fail:
    li   a0, 0
    ret

# uint8_t build_table(uint8_t *diameter)
build_table:
    addi sp, sp, -48
    sw   ra, 44(sp)
    sw   s0, 40(sp)
    sw   s1, 36(sp)
    sw   s2, 32(sp)
    sw   s3, 28(sp)
    sw   s4, 24(sp)
    mv   s4, a0              # diameter pointer

    # 1. 建立 perm_move[3][5040]
    li   s0, 0               # rank = 0
    li   s1, 5040
bt_perm_loop:
    mv   a0, s0
    mv   a1, sp              # &state (sp+0)
    jal  ra, unrank_perm
    li   s2, 0               # face = 0
    la   s3, perm_move
bt_perm_face:
    mv   a0, sp              # &state
    addi a1, sp, 16          # &next (sp+16)
    mv   a2, s2
    jal  ra, quarter_turn
    addi a0, sp, 16
    jal  ra, rank_perm
    slli t0, s0, 1
    add  t0, s3, t0
    sh   a0, 0(t0)           # perm_move[face][rank] = rank_perm(&next)
    li   t1, 10080           # 5040 * 2 bytes stride
    add  s3, s3, t1
    addi s2, s2, 1
    li   t2, 3
    bne  s2, t2, bt_perm_face
    addi s0, s0, 1
    bne  s0, s1, bt_perm_loop

    # 2. 建立 ori_move[3][729]
    li   s0, 0               # rank = 0
    li   s1, 729
bt_ori_loop:
    mv   a0, s0
    mv   a1, sp
    jal  ra, unrank_ori
    li   s2, 0               # face = 0
    la   s3, ori_move
bt_ori_face:
    mv   a0, sp
    addi a1, sp, 16
    mv   a2, s2
    jal  ra, quarter_turn
    addi a0, sp, 16
    jal  ra, rank_ori
    slli t0, s0, 1
    add  t0, s3, t0
    sh   a0, 0(t0)           # ori_move[face][rank] = rank_ori(&next)
    li   t1, 1458            # 729 * 2 bytes stride
    add  s3, s3, t1
    addi s2, s2, 1
    li   t2, 3
    bne  s2, t2, bt_ori_face
    addi s0, s0, 1
    bne  s0, s1, bt_ori_loop

    # 3. BFS 建立 pdb_perm
    la   t0, pdb_perm
    li   t1, 5040
    li   t2, 0xFF
bt_init_p:
    sb   t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, bt_init_p

    la   s0, pdb_perm
    sb   zero, 0(s0)         # pdb_perm[0] = 0
    la   s1, queue
    sh   zero, 0(s1)         # queue[0] = 0
    li   t0, 0               # head = 0
    li   t1, 1               # tail = 1
    li   t6, 0               # max_dist = 0
    li   a6, 0xFF
bt_bfs_p:
    bgeu t0, t1, bt_bfs_p_done
    slli t2, t0, 1
    add  t2, s1, t2
    lhu  t3, 0(t2)           # p = queue[head]
    addi t0, t0, 1
    add  t2, s0, t3
    lbu  t4, 0(t2)           # d = pdb_perm[p]
    bleu t4, t6, bt_skip_max
    mv   t6, t4
bt_skip_max:
    addi t4, t4, 1           # d + 1
    la   s2, perm_move
    li   a2, 3               # 3 faces
    li   a7, 10080           # stride
bt_bfs_p_face:
    mv   t5, t3              # next_p = p
    li   a3, 3               # 3 turns
bt_bfs_p_turn:
    slli a4, t5, 1
    add  a4, s2, a4
    lhu  t5, 0(a4)           # next_p = perm_move[face][next_p]
    add  a5, s0, t5
    lbu  a4, 0(a5)
    bne  a4, a6, bt_bfs_p_visited
    sb   t4, 0(a5)           # pdb_perm[next_p] = d + 1
    slli a4, t1, 1
    add  a4, s1, a4
    sh   t5, 0(a4)           # queue[tail++] = next_p
    addi t1, t1, 1
bt_bfs_p_visited:
    addi a3, a3, -1
    bnez a3, bt_bfs_p_turn
    add  s2, s2, a7
    addi a2, a2, -1
    bnez a2, bt_bfs_p_face
    j    bt_bfs_p
bt_bfs_p_done:
    beqz s4, bt_no_diam
    sb   t6, 0(s4)           # *diameter = max_dist
bt_no_diam:

    # 4. BFS 建立 pdb_ori
    la   t0, pdb_ori
    li   t1, 729
    li   t2, 0xFF
bt_init_o:
    sb   t2, 0(t0)
    addi t0, t0, 1
    addi t1, t1, -1
    bnez t1, bt_init_o

    la   s0, pdb_ori
    sb   zero, 0(s0)
    sh   zero, 0(s1)         # queue[0] = 0
    li   t0, 0               # head = 0
    li   t1, 1               # tail = 1
    li   a6, 0xFF
bt_bfs_o:
    bgeu t0, t1, bt_bfs_o_done
    slli t2, t0, 1
    add  t2, s1, t2
    lhu  t3, 0(t2)           # o = queue[head]
    addi t0, t0, 1
    add  t2, s0, t3
    lbu  t4, 0(t2)
    addi t4, t4, 1           # d + 1
    la   s2, ori_move
    li   a2, 3
    li   a7, 1458            # stride = 729 * 2
bt_bfs_o_face:
    mv   t5, t3              # next_o = o
    li   a3, 3
bt_bfs_o_turn:
    slli a4, t5, 1
    add  a4, s2, a4
    lhu  t5, 0(a4)           # next_o = ori_move[face][next_o]
    add  a5, s0, t5
    lbu  a4, 0(a5)
    bne  a4, a6, bt_bfs_o_visited
    sb   t4, 0(a5)
    slli a4, t1, 1
    add  a4, s1, a4
    sh   t5, 0(a4)
    addi t1, t1, 1
bt_bfs_o_visited:
    addi a3, a3, -1
    bnez a3, bt_bfs_o_turn
    add  s2, s2, a7
    addi a2, a2, -1
    bnez a2, bt_bfs_o_face
    j    bt_bfs_o
bt_bfs_o_done:
    li   a0, 1
    lw   ra, 44(sp)
    lw   s0, 40(sp)
    lw   s1, 36(sp)
    lw   s2, 32(sp)
    lw   s3, 28(sp)
    lw   s4, 24(sp)
    addi sp, sp, 48
    ret

# uint8_t ida_search(uint16_t p, uint16_t o, uint8_t g, uint8_t bound, uint8_t last_face)
ida_search:
    la   t0, pdb_perm
    add  t0, t0, a0
    lbu  t1, 0(t0)           # h = pdb_perm[p]
    la   t0, pdb_ori
    add  t0, t0, a1
    lbu  t2, 0(t0)           # ho = pdb_ori[o]
    bleu t2, t1, ida_h_ok
    mv   t1, t2
ida_h_ok:
    add  t1, a2, t1          # f = g + h
    bleu t1, a3, ida_not_pruned
    mv   a0, t1
    ret
ida_not_pruned:
    or   t0, a0, a1
    bnez t0, ida_expand
    la   t0, solution_len
    sb   a2, 0(t0)
    li   a0, 0
    ret
ida_expand:
    addi sp, sp, -48
    sw   ra, 44(sp)
    sw   s0, 40(sp)
    sw   s1, 36(sp)
    sw   s2, 32(sp)
    sw   s3, 28(sp)
    sw   s4, 24(sp)
    sw   s5, 20(sp)
    sw   s6, 16(sp)
    sw   s7, 12(sp)
    sw   s8, 8(sp)
    sw   s9, 4(sp)

    mv   s0, a0              # p
    mv   s1, a1              # o
    mv   s2, a2              # g
    mv   s3, a3              # bound
    mv   s4, a4              # last_face
    li   s5, 0xFF            # min_next = 0xFF
    li   s6, 0               # face = 0
    la   s8, perm_move
    la   s9, ori_move
ida_face_loop:
    beq  s6, s4, ida_next_face
    mv   t3, s0              # next_p = p
    mv   t4, s1              # next_o = o
    li   s7, 0               # turn = 0
ida_turn_loop:
    sw   t3, 0(sp)           # 暫存前一步狀態
    slli t0, t3, 1
    add  t0, s8, t0
    lhu  t3, 0(t0)           # next_p = perm_move[face][next_p]
    slli t0, t4, 1
    add  t0, s9, t0
    lhu  t4, 0(t0)           # next_o = ori_move[face][next_o]
    sw   t3, 0(sp)
    sh   t4, 2(sp)

    slli t0, s6, 1
    add  t0, t0, s6
    add  t0, t0, s7          # face * 3 + turn
    la   t1, solution
    add  t1, t1, s2
    sb   t0, 0(t1)           # solution[g] = move

    mv   a0, t3
    mv   a1, t4
    addi a2, s2, 1
    mv   a3, s3
    mv   a4, s6
    jal  ra, ida_search
    beqz a0, ida_found
    bgeu a0, s5, ida_no_min
    mv   s5, a0
ida_no_min:
    lhu  t3, 0(sp)
    lhu  t4, 2(sp)
    addi s7, s7, 1
    li   t0, 3
    bne  s7, t0, ida_turn_loop
ida_next_face:
    li   t0, 10080
    add  s8, s8, t0
    li   t0, 1458
    add  s9, s9, t0
    addi s6, s6, 1
    li   t0, 3
    bne  s6, t0, ida_face_loop
    mv   a0, s5
ida_found:
    lw   ra, 44(sp)
    lw   s0, 40(sp)
    lw   s1, 36(sp)
    lw   s2, 32(sp)
    lw   s3, 28(sp)
    lw   s4, 24(sp)
    lw   s5, 20(sp)
    lw   s6, 16(sp)
    lw   s7, 12(sp)
    lw   s8, 8(sp)
    lw   s9, 4(sp)
    addi sp, sp, 48
    ret

# int parse_state(const char *input, state_t *state)
parse_state:
    addi sp, sp, -16
    sw   ra, 12(sp)
    li   t0, 0               # i = 0
    li   t6, 7
    li   t3, 49              # '1'
    li   t4, 55              # '7'
ps_p_loop:
    add  t1, a0, t0
    lbu  t2, 0(t1)
    bltu t2, t3, ps_fail
    bgtu t2, t4, ps_fail
    sub  t2, t2, t3
    add  t1, a1, t0
    sb   t2, 0(t1)
    addi t0, t0, 1
    bne  t0, t6, ps_p_loop

    li   t0, 0
    li   t4, 51              # '3'
ps_o_loop:
    add  t1, a0, t0
    lbu  t2, 7(t1)
    bltu t2, t3, ps_fail
    bgtu t2, t4, ps_fail
    sub  t2, t2, t3
    add  t1, a1, t0
    sb   t2, 7(t1)
    addi t0, t0, 1
    bne  t0, t6, ps_o_loop

    lbu  t2, 14(a0)
    bnez t2, ps_fail
    mv   a0, a1
    jal  ra, valid
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret
ps_fail:
    li   a0, 0
    lw   ra, 12(sp)
    addi sp, sp, 16
    ret

# int main(void)
main:
    addi sp, sp, -32
    sw   ra, 28(sp)
    sw   s0, 24(sp)
    sw   s1, 20(sp)
    sw   s2, 16(sp)

    la   a0, test_input
    mv   a1, sp              # &state (sp+0)
    jal  ra, parse_state
    beqz a0, main_err2

    addi a0, sp, 15          # &diameter
    jal  ra, build_table
    beqz a0, main_err1

    mv   a0, sp
    jal  ra, rank_perm
    mv   s0, a0              # p

    mv   a0, sp
    jal  ra, rank_ori
    mv   s1, a0              # o

    la   t0, pdb_perm
    add  t0, t0, s0
    lbu  s2, 0(t0)           # bound = pdb_perm[p]
    la   t0, pdb_ori
    add  t0, t0, s1
    lbu  t1, 0(t0)
    bleu t1, s2, main_ida_loop
    mv   s2, t1
main_ida_loop:
    mv   a0, s0
    mv   a1, s1
    li   a2, 0
    mv   a3, s2
    li   a4, 3
    jal  ra, ida_search
    beqz a0, main_done
    mv   s2, a0
    j    main_ida_loop

main_done:
    la   s0, solution
    la   s1, solution_len
    lbu  s1, 0(s1)           # s1 = solution_len
    li   s2, 0               # i = 0
    la   t2, move_names
print_loop:
    bgeu s2, s1, print_newline
    beqz s2, print_move
    li   a0, 32              # 印出空白 ' '
    li   a7, 11              # Ripes PrintChar
    ecall
print_move:
    add  t0, s0, s2
    lbu  t0, 0(t0)           # move = solution[i]
    slli t0, t0, 2           # move * 4 (每個字串剛好佔 4 bytes)
    add  a0, t2, t0          # &move_names[move]
    li   a7, 4               # Ripes PrintString
    ecall
    addi s2, s2, 1
    j    print_loop
print_newline:
    li   a0, 10              # 印出換行 '\n'
    li   a7, 11
    ecall
    li   a0, 0
    j    main_exit
main_err1:
    li   a0, 1
    j    main_exit
main_err2:
    li   a0, 2
main_exit:
    lw   ra, 28(sp)
    lw   s0, 24(sp)
    lw   s1, 20(sp)
    lw   s2, 16(sp)
    addi sp, sp, 32
    ret

.data
move_names:
    .string "R"
    .zero 2
    .string "R2"
    .zero 1
    .string "R'"
    .zero 1
    .string "B"
    .zero 2
    .string "B2"
    .zero 1
    .string "B'"
    .zero 1
    .string "D"
    .zero 2
    .string "D2"
    .zero 1
    .string "D'"
    .zero 1
source:
    .byte 1, 4, 2, 0, 3, 5, 6
    .byte 0, 1, 2, 4, 5, 6, 3
    .byte 0, 2, 5, 3, 1, 4, 6
twist:
    .byte 1, 2, 0, 2, 1, 0, 0
    .byte 0, 0, 0, 1, 2, 1, 2
    .byte 0, 0, 0, 0, 0, 0, 0
    .align 2
fact:
    .half 720, 120, 24, 6, 2, 1, 1
    .align 2
pow3:
    .half 243, 81, 27, 9, 3, 1
test_input:
    .string "21345671111111"
    .align 2
perm_move:
    .zero 30240
ori_move:
    .zero 4374
    .align 2
queue:
    .zero 10080
pdb_perm:
    .zero 5040
pdb_ori:
    .zero 729
solution:
    .zero 12
solution_len:
    .zero 1