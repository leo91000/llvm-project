; REQUIRES: powerpc-registered-target, x86-registered-target
; RUN: opt -passes="globalopt" -mtriple=powerpc64le-unknown-linux-gnu -ppc-enable-coldcc < %s -o /dev/null -debug-pass-manager 2>&1 | FileCheck %s --check-prefix=COLDSCAN
; RUN: opt -strip-debug -S < %s | opt -passes="globalopt" -mtriple=powerpc64le-unknown-linux-gnu -ppc-enable-coldcc -o /dev/null -debug-pass-manager 2>&1 | FileCheck %s --check-prefix=COLDSCAN
; RUN: opt -passes="globalopt" -mtriple=x86_64-unknown-linux-gnu < %s -o /dev/null -debug-pass-manager 2>&1 | FileCheck %s --check-prefix=NOCOLDSCAN --implicit-check-not=BlockFrequencyAnalysis --implicit-check-not=LoopAnalysis
; RUN: opt -strip-debug -S < %s | opt -passes="globalopt" -mtriple=x86_64-unknown-linux-gnu -o /dev/null -debug-pass-manager 2>&1 | FileCheck %s --check-prefix=NOCOLDSCAN --implicit-check-not=BlockFrequencyAnalysis --implicit-check-not=LoopAnalysis

; Make sure that the call to dbg.declare does not prevent running BlockFrequency
; and (especially) Loop Analysis when the target uses the cold-call scan.
; Later passes (e.g. instcombine) may behave in different ways depending on if
; LoopInfo is available or not. Therefore, letting GlobalOpt run or not run
; LoopAnalysis depending on the presence of a dbg.declare may make the compiler
; generate different code with and without debug info.
; A target which does not use coldcc must skip these analyses both with and
; without debug info.

; COLDSCAN: Running pass: GlobalOptPass on [module]
; COLDSCAN: Running analysis: BlockFrequencyAnalysis on h
; COLDSCAN: Running analysis: LoopAnalysis on h
; NOCOLDSCAN: Running pass: GlobalOptPass on [module]

define i16 @h(ptr %k) {
entry:
  call void @llvm.dbg.declare(metadata ptr %k, metadata !1, metadata !DIExpression()), !dbg !22
  %call = call i16 @gaz()
  ret i16 %call
}

; Function Attrs: nocallback nofree nosync nounwind readnone speculatable willreturn
declare void @llvm.dbg.declare(metadata, metadata, metadata)  #0

define internal i16 @gaz() {
entry:
  ret i16 0
}

attributes #0 = { nocallback nofree nosync nounwind readnone speculatable willreturn }

!llvm.dbg.cu = !{!17}
!llvm.module.flags = !{!0}

!0 = !{i32 2, !"Debug Info Version", i32 3}
!1 = !DILocalVariable(name: "k", arg: 1, scope: !2, file: !3, line: 13, type: !19)
!2 = distinct !DISubprogram(name: "h", scope: !3, file: !3, line: 13, type: !4, scopeLine: 13, flags: DIFlagAllCallsDescribed, spFlags: DISPFlagLocalToUnit | DISPFlagDefinition | DISPFlagOptimized, unit: !17, retainedNodes: !21)
!3 = !DIFile(filename: "foo2.c", directory: "/bar")
!4 = !DISubroutineType(types: !5)
!5 = !{!19}
!17 = distinct !DICompileUnit(language: DW_LANG_C99, file: !3, producer: "clang version 16", isOptimized: true, runtimeVersion: 0, emissionKind: FullDebug, retainedTypes: !18, globals: !20, splitDebugInlining: false, nameTableKind: None)
!18 = !{!19}
!19 = !DIBasicType(name: "int", size: 16, encoding: DW_ATE_signed)
!20 = !{}
!21 = !{!1}
!22 = !DILocation(line: 13, column: 27, scope: !2)
