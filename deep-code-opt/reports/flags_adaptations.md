# Flags do flags.env omitidas no modulo de kernel (e por que)
- -march=native -mavx2 -mfma : kernel proibe SIMD/FPU em modulo (Kbuild forca -mno-sse -mno-sse2 -mno-avx); usar corromperia registradores de processos. Mantido -mtune=native (so agenda, sem ISA nova).
- -fno-stack-protector : kernel tem CONFIG_STACKPROTECTOR_STRONG; tirar desligaria protecao de seguranca do kernel.
- -gline-tables-only -fdebug-info-for-profiling : CONFIG_DEBUG_INFO_BTF_MODULES exige debug info completo; trocaria/quebraria o BTF do modulo.
- -Wl,-O1 -Wl,--sort-common -Wl,--as-needed -Wl,-z,relro -Wl,-z,now -Wl,--hash-style=gnu -Wl,--emit-relocs -Wl,-z,nopack-relative-relocs -fuse-ld=lld : flags de link de executavel/.so; modulo e linkado por Kbuild com ld.lld -r (objeto relocavel), nao se aplicam.
- -Wl,--call-graph-profile-sort=cdsort : so atua no link final; modulo .ko e ld -r e o kernel faz o layout ao carregar. Nao aplicavel.

## -fno-plt (removida apos build)
Kernel recusa o modulo: "module: nvidia: Unknown rela relocation: 42" (R_X86_64_REX_GOTPCRELX, 2918 relocs geradas por -fno-plt; stock tem 0). Loader de modulos do kernel nao suporta GOT. Removida.
