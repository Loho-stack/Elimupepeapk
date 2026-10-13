# Bundled fonts

| File | Family | Use | Licence file | Source |
|---|---|---|---|---|
| Fredoka.ttf (variable wdth,wght) | Fredoka | headings | licenses/OFL-Fredoka.txt | github.com/google/fonts ofl/fredoka |
| Nunito.ttf, Nunito-Italic.ttf (variable wght) | Nunito | body | licenses/OFL-Nunito.txt | github.com/google/fonts ofl/nunito |
| OpenDyslexic3-Regular.ttf, OpenDyslexic3-Bold.ttf | OpenDyslexic | accessibility font swap | licenses/OFL-OpenDyslexic.txt | npm open-dyslexic 1.0.3, `ttf/OpenDyslexic3-*` |

## OpenDyslexic licence note
OpenDyslexic exists in two licence lines:
- v1/v2 (`OpenDyslexic-*.ttf`): based on Bitstream Vera, name table says Bitstream licence plus CC BY 3.0. NOT used.
- v3 (`OpenDyslexic3-*.ttf`, Abbie Gonzalez): SIL OFL 1.1, name table licence "SIL Open Font License, 1.1".
  This is what is bundled, and it is the same line the web app self-hosts (its LICENSE text is copied
  verbatim into licenses/OFL-OpenDyslexic.txt). The npm package README still describes the old Bitstream
  licence for the package as a whole; the v3 files carry the OFL in their own metadata.
If legal wants the Bitstream/CC-BY v1 files instead, the licence text is in the npm package README (lines 96-118).

## Checksums (sha256)
2ba02e68b152868aef9ba28e24b3648c7d457fe6f25c761f2c2c53fb61a73fc8 *Fredoka.ttf
bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207 *Nunito.ttf
b520cc871868b0acfca1beda875df7f4a44ebce914f8a89f83977fc9c09529c8 *Nunito-Italic.ttf
159a62d2c629cb16867fd2822cbcf64d75e6fb3c915c9d2a14b491e9a6a5f605 *OpenDyslexic3-Bold.ttf
54c5c2129fb7ba2c48fa3cb75379f0ea47cfcc24e20f1956a6c080d1efb480a3 *OpenDyslexic3-Regular.ttf
