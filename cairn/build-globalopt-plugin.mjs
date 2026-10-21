#!/usr/bin/env node
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
import { spawnSync } from 'node:child_process'
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import path from 'node:path'
import process from 'node:process'

const options = {}
for (let index = 2; index < process.argv.length; index += 2) {
  const key = process.argv[index]
  const value = process.argv[index + 1]
  if (!key?.startsWith('--') || !value) throw new Error('Expected --name value arguments')
  options[key.slice(2)] = value
}
for (const name of ['llvm-build', 'llvm-dylib', 'out']) {
  if (!options[name]) throw new Error(`Missing --${name}`)
}
const source = path.dirname(path.dirname(new URL(import.meta.url).pathname))
const output = path.resolve(options.out)
const generated = path.resolve(options['llvm-build'], 'include')
const library = path.resolve(options['llvm-dylib'])
const originalFile = 'llvm/lib/Transforms/IPO/GlobalOpt.cpp'
const base = options.base ?? 'dcc3606807c989700e0ac1cac18c31741bcd40d9'
const reference = spawnSync('git', ['show', `${base}:${originalFile}`], { cwd: source, encoding: 'utf8' })
if (reference.status !== 0) throw new Error('Cannot read the pinned reference source')
const patched = readFileSync(path.join(source, originalFile), 'utf8')
mkdirSync(output, { recursive: true })
const records = []
for (const variant of ['reference', 'patched']) {
  const classname = variant === 'reference' ? 'CairnReferenceGlobalOptPass' : 'CairnPatchedGlobalOptPass'
  const token = `cairn-globalopt-${variant}`
  let content = variant === 'reference' ? reference.stdout : patched
  content = content.replace('#define DEBUG_TYPE "globalopt"', `#define DEBUG_TYPE "${token}"`)
  for (const option of ['optimize-non-fmv-callers', 'max-ifunc-versions', 'enable-coldcc-stress-test', 'coldcc-rel-freq']) {
    content = content.replaceAll(`"${option}"`, `"${token}-${option}"`)
  }
  const copied = path.join(output, `GlobalOpt.${variant}.cpp`)
  const binary = path.join(output, `${token}.so`)
  writeFileSync(copied, content)
  const args = [
    '-std=c++17', '-O3', '-DNDEBUG', '-fPIC', '-fno-rtti', '-shared',
    `-DGlobalOptPass=${classname}`, `-DCAIRN_PASS_CLASS=${classname}`,
    `-DCAIRN_PASS_TOKEN="${token}"`,
    '-I', path.join(source, 'llvm/include'), '-I', generated,
    copied, path.join(source, 'cairn/GlobalOptPlugin.cpp'), library,
    `-Wl,-rpath,${path.dirname(library)}`, '-Wl,-z,defs', '-o', binary,
  ]
  const started = performance.now()
  const result = spawnSync(options.cxx ?? 'clang++', args, { cwd: source, stdio: 'inherit' })
  records.push({ variant, source: copied, binary, compiler: options.cxx ?? 'clang++', args, elapsedSeconds: (performance.now() - started) / 1000, exitCode: result.status })
  writeFileSync(path.join(output, 'build.json'), `${JSON.stringify({ base, records }, null, 2)}\n`)
  if (result.status !== 0) process.exit(result.status ?? 1)
}
