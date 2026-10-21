; REQUIRES: x86-registered-target
; RUN: opt -passes=globalopt -disable-output -debug-pass-manager -mtriple=x86_64-unknown-linux-gnu < %s 2>&1 | FileCheck %s --check-prefix=ANALYSIS --implicit-check-not=BlockFrequencyAnalysis
; RUN: opt -passes=globalopt -S -mtriple=x86_64-unknown-linux-gnu < %s | FileCheck %s --check-prefix=IR
;
; A cold direct call used to request block frequencies even on targets which
; never select coldcc. Keep the ordinary fastcc transformation.
;
; ANALYSIS: Running pass: GlobalOptPass
; IR-LABEL: define internal fastcc i32 @callee(
; IR-LABEL: define i32 @caller(
; IR: call fastcc i32 @callee(

; Intrinsic declarations must not be passed to TargetIRAnalysis.
declare void @llvm.lifetime.start.p0(ptr nocapture)

define internal i32 @callee(ptr %p) {
entry:
  %v = load i32, ptr %p
  ret i32 %v
}

define i32 @caller(ptr %p, i1 %cold) {
entry:
  br i1 %cold, label %slow, label %done, !prof !0
slow:
  %v = call i32 @callee(ptr %p)
  ret i32 %v
done:
  ret i32 0
}
!0 = !{!"branch_weights", i32 1, i32 10000}
