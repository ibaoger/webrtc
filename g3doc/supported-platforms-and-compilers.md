<!-- go/cmark -->
<!--* freshness: {owner: 'mbonadei' reviewed: '2024-09-04'} *-->

# WebRTC supported plaftorms and compilers

## Operating systems and CPUs

The list of officially supported operating systems and CPUs is:

*   Android: armeabi-v7a, arm64-v8a, x86, x86_64.
*   iOS: arm64, x86_64.
*   Linux: armeabi-v7a, arm64-v8a, x86, x86_64.
*   macOS: x86_64, arm64.
*   Windows: x86_64.

Other platforms are not officially supported (which means there is no CI
coverage for them) but patches to keep WebRTC working with them are welcomed by
the WebRTC Team.

## Compilers

WebRTC officially supports clang on all the supported platforms. The clang
version officially supported is the one used by Chromium (hence the version is
really close to Tip of Tree and can be checked
[here](https://source.chromium.org/chromium/chromium/src/+/main:tools/clang/scripts/update.py)
by looking at the value of `CLANG_REVISION`).

See also
[here](https://source.chromium.org/chromium/chromium/src/+/main:docs/clang.md)
for some clang related documentation from Chromium.

Other compilers are not officially supported (which means there is no CI
coverage for them) but patches to keep WebRTC working with them are welcomed by
the WebRTC Team.
