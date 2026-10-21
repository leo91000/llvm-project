; REQUIRES: powerpc-registered-target
; RUN: opt -passes=globalopt -ppc-enable-coldcc -S -mtriple=powerpc64le-unknown-linux-gnu < %s | FileCheck %s
;
; A target that requests coldcc must still receive the original cold-call scan.
;
; CHECK-LABEL: define internal coldcc i32 @callee(
; CHECK-LABEL: define i32 @caller(
; CHECK: call coldcc i32 @callee(

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
