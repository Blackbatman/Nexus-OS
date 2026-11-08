# 07 — Legal & Ethical Posture (condensed)

Full text: `NOTICE.md`. The four commitments, in order:

1. **Owner's-hardware research.** Nothing here targets consoles or machines you
   do not own. Jailbreaking voids warranties and can ban consoles — the
   operator accepts that; the software does not pretend otherwise.
2. **No piracy surface.** No game decryption, no firmware dumps, no license
   circumvention. Windows/macOS media are always **user-supplied and licensed**
   (`packaging/windows-media/`, `packaging/macos-vm/`); the repo ships none.
3. **macOS honesty.** Bare-metal macOS on PS5 is Apple-EULA gray zone — the
   engineering is included and labeled; the Apple-licensed clean path is the
   terminal-mac guest on Apple silicon. macOS/ARM on x86 is stated as
   impossible rather than faked.
4. **RE tools scoped.** REA/radare2/craft-anything analyze artifacts this
   project builds. Pointing them at anti-piracy systems is outside scope and
   outside charter.

Downstream distributors: third-party licenses in `NOTICE.md` §6 require
attribution; GPL components stay GPL under you. Everything ships AS IS, no
warranty.
