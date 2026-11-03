#!/usr/bin/env python3
"""Build the experimental waveform zoom patch for rekordbox 7.2.14 x64.

Usage: python3 patch.py <original rekordbox.exe> <output exe> <manifest.json>
Requires GNU binutils (as, ld, objcopy, nm). Keeps the source when output differs.
Visual waveform coverage is not confirmed. Invalidates Authenticode signing.
"""
import hashlib, json, os, struct, subprocess, sys, tempfile

ORIGINAL_SHA256 = "f6359b6b3553e5f81e55444b28b7b56aa6f80f7bb7eb88f3c84d865d821ad5a9"
IMAGE_BASE = 0x140000000
TEXT_RVA = 0x1000
TEXT_RAW = 0x400
TEXT_VSIZE = 0x32C6A7C
TEXT_RAWSIZE = 0x32C6C00
CAVE_VA = IMAGE_BASE + TEXT_RVA + TEXT_VSIZE  # 0x1432c7a7c
HERE = os.path.dirname(os.path.abspath(__file__))
TARGETS = dict(
    MANAGER_PTR=0x145C5C338,
    HANDLER_CMP=0x142428108,
    CONV_NORMAL_EPILOG=0x1423F28B4,
    CONV_114_EPILOG=0x1423F28C6,
    CONV_112_EPILOG=0x1423F28D8,
    GRID_EXIT=0x1418E91CC,
    GRID_NEXT_BEAT=0x1418E91B2,
    GRID_RESUME=0x1418E8CA0,
)


def file_offset(va):
    rva = va - IMAGE_BASE
    assert TEXT_RVA <= rva < TEXT_RVA + TEXT_RAWSIZE, hex(va)
    return rva - TEXT_RVA + TEXT_RAW


def assemble():
    with tempfile.TemporaryDirectory() as tmp:
        obj, elf, flat = (os.path.join(tmp, n) for n in ("s.o", "s.elf", "s.bin"))
        subprocess.run(["as", "--64", "-o", obj, os.path.join(HERE, "stubs.s")], check=True)
        defsyms = ["--defsym=%s=%#x" % kv for kv in TARGETS.items()]
        subprocess.run(["ld", "-Ttext=%#x" % CAVE_VA, "-e", "_start", *defsyms, "-o", elf, obj], check=True)
        subprocess.run(["objcopy", "-O", "binary", "-j", ".text", elf, flat], check=True)
        nm = subprocess.run(["nm", elf], check=True, capture_output=True, text=True).stdout
        syms = {name: int(addr, 16) for addr, kind, name in (l.split() for l in nm.splitlines() if len(l.split()) == 3) if kind in "tT"}
        return open(flat, "rb").read(), syms


def jmp(src, dst, length):
    rel = dst - (src + 5)
    return b"\xe9" + struct.pack("<i", rel) + b"\xcc" * (length - 5)


def main(src, out, manifest_path):
    data = bytearray(open(src, "rb").read())
    assert hashlib.sha256(data).hexdigest() == ORIGINAL_SHA256, "input is not the original rb.exe"

    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    opt_size = struct.unpack_from("<H", data, e_lfanew + 20)[0]
    text_hdr = e_lfanew + 24 + opt_size
    assert data[text_hdr:text_hdr + 8] == b".text\0\0\0"
    assert struct.unpack_from("<IIII", data, text_hdr + 8) == (TEXT_VSIZE, TEXT_RVA, TEXT_RAWSIZE, TEXT_RAW)

    stubs, sym = assemble()
    cave_end = CAVE_VA + len(stubs)
    assert cave_end <= IMAGE_BASE + TEXT_RVA + TEXT_RAWSIZE, "stubs exceed .text raw padding"
    assert sym["stubs_end"] == cave_end

    decoder_disp = sym["decoder_window_seconds"] - 0x1423D3839
    sites = [
        ("normal zoom-out max", 0x142428103, "b8 07 00 00 00", jmp(0x142428103, sym["handler_max"], 5)),
        ("converter normal bound 7->11", 0x1423F282D, "83 fb 07", bytes.fromhex("83 fb 0b")),
        ("converter normal table read", 0x1423F28AD, "8b 84 90 98 6c a7 05", jmp(0x1423F28AD, sym["conv_normal"], 7)),
        ("converter 0x114 table read", 0x1423F28BF, "8b 84 90 d8 6c a7 05", jmp(0x1423F28BF, sym["conv_hw114"], 7)),
        ("converter 0x112 table read", 0x1423F28D1, "8b 84 90 b8 6c a7 05", jmp(0x1423F28D1, sym["conv_hw112"], 7)),
        ("grid normal-branch filter", 0x1418E8C97, "45 85 c0 0f 88 2c 05 00 00", jmp(0x1418E8C97, sym["grid_filter"], 9)),
        ("decoder profile window load", 0x1423D3831, "c5 fa 10 05 a7 1c 33 01", bytes.fromhex("c5 fa 10 05") + struct.pack("<i", decoder_disp)),
        ("stubs in .text raw padding", CAVE_VA, "00" * len(stubs), stubs),
    ]

    changes = []
    for name, va, orig_hex, new in sites:
        off = file_offset(va)
        orig = bytes.fromhex(orig_hex)
        assert len(orig) == len(new), name
        assert data[off:off + len(orig)] == orig, "original bytes differ at %s" % name
        data[off:off + len(new)] = new
        changes.append(dict(name=name, va="%#x" % va, file_offset="%#x" % off, length=len(new),
                            original=orig.hex(" "), patched=new.hex(" ")))

    vs_off = text_hdr + 8
    new_vsize = cave_end - IMAGE_BASE - TEXT_RVA
    orig_vs = bytes(data[vs_off:vs_off + 4])
    struct.pack_into("<I", data, vs_off, new_vsize)
    changes.append(dict(name=".text VirtualSize", va=None, file_offset="%#x" % vs_off, length=4,
                        original=orig_vs.hex(" "), patched=bytes(data[vs_off:vs_off + 4]).hex(" ")))

    assert hashlib.sha256(data).hexdigest() == "1d0e4e5622a1c9f3e9e79cc29e0392d3bb06a552437530c03fe0ca424fac47f8", "output differs from the recorded candidate"
    open(out, "wb").write(data)
    manifest = dict(
        target_version="rekordbox 7.2.14 x64",
        target_product_version="7.2.14.0323",
        status="experimental; visual waveform coverage not confirmed",
        limitations=[
            "Invalidates Authenticode signing; PE checksum remains unchanged.",
            "Leaf detours have no unwind metadata.",
            "Normal-mode alternate-index caller and other wide-range views need runtime verification.",
        ],
        input_sha256=ORIGINAL_SHA256,
        output_sha256=hashlib.sha256(data).hexdigest(),
        output_size=len(data),
        stub_symbols={k: "%#x" % v for k, v in sorted(sym.items(), key=lambda kv: kv[1])},
        changed_bytes=sum(a != b for a, b in zip(open(src, "rb").read(), data)),
        changes=changes,
    )
    json.dump(manifest, open(manifest_path, "w"), indent=1)
    print(manifest["output_sha256"], "changed bytes:", manifest["changed_bytes"], "stub bytes:", len(stubs))


if __name__ == "__main__":
    main(*sys.argv[1:4])
