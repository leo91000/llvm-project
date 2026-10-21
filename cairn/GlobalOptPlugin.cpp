// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
// Build the fork's GlobalOpt as an independently measurable pass. The original
// pass remains available, and this plugin does not change a compiler pipeline.
#include "llvm/Transforms/IPO/GlobalOpt.h"
#undef GlobalOptPass

#include "llvm/Passes/PassBuilder.h"
#include "llvm/Plugins/PassPlugin.h"

extern "C" LLVM_ATTRIBUTE_WEAK llvm::PassPluginLibraryInfo
llvmGetPassPluginInfo() {
  return {LLVM_PLUGIN_API_VERSION, CAIRN_PASS_TOKEN, LLVM_VERSION_STRING,
          [](llvm::PassBuilder &PB) {
            PB.registerPipelineParsingCallback(
                [](llvm::StringRef Name, llvm::ModulePassManager &MPM,
                   llvm::ArrayRef<llvm::PassBuilder::PipelineElement>) {
                  if (Name != CAIRN_PASS_TOKEN)
                    return false;
                  MPM.addPass(llvm::CAIRN_PASS_CLASS());
                  return true;
                });
          }};
}
