# Leaf detours for rb.exe 7.2.14 (sha256 f6359b6b...), linked flat at the
# start of .text trailing padding. No calls, no stack use, so no unwind data.
# Upper-case symbols are absolute original-image addresses from patch.py.
        .intel_syntax noprefix

        .text
        .globl _start
_start:
decoder_window_seconds:
        .float 100.0
normal_ranges:
        .long 1000, 2000, 3000, 4000, 8000, 16000, 24000
        .long 32000, 48000, 64000, 96000

# Replaces `mov eax,7` before the normal zoom-out clamp. Hardware 0x112/0x114
# keeps its seven-entry tables; the effective type follows FUN_1423f27f0.
handler_max:
        mov r10, [rip + MANAGER_PTR]
        mov eax, 7
        test r10, r10
        jz 2f
        mov r11d, [r10 + 0x10]
        cmp r11d, 0x1002
        je 1f
        cmp r11d, 0x1004
        jne 3f
1:      cmp byte ptr [r10 + 0x1c], 0
        je 3f
        mov r11d, [r10 + 0x18]
3:      cmp r11d, 0x112
        je 2f
        cmp r11d, 0x114
        je 2f
        mov eax, 11
2:      jmp HANDLER_CMP

conv_normal:
        lea r10, [rip + normal_ranges]
        mov eax, [r10 + rdx*4]
        jmp CONV_NORMAL_EPILOG

# Normal-mode indices 7..10 fall back to stock index 4 on hardware tables.
conv_hw114:
        mov r10, rdx
        test sil, sil
        jnz 1f
        cmp r10d, 7
        jb 1f
        mov r10d, 4
1:      mov eax, [rax + r10*4 + 0x5a76cd8]
        jmp CONV_114_EPILOG

conv_hw112:
        mov r10, rdx
        test sil, sil
        jnz 1f
        cmp r10d, 7
        jb 1f
        mov r10d, 4
1:      mov eax, [rax + r10*4 + 0x5a76cb8]
        jmp CONV_112_EPILOG

# Normal grid branch: beyond 24000 ms draw only downbeats.
grid_filter:
        test r8d, r8d
        js GRID_EXIT
        cmp dword ptr [rsi + 0x804], 24000
        jle 1f
        mov r10d, r12d
        cmp word ptr [r13 + r10*8], 1
        jne GRID_NEXT_BEAT
1:      jmp GRID_RESUME
stubs_end:
