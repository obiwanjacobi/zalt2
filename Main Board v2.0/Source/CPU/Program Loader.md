# Program Loader

How applications are loaded.

- 4k segmentation and relocation
- fixed data page (stack, data)
- function jump table
- how to compile C into segmented relocatable code

## Current Working Assumptions

- MMU page size is 4 KB.
- Code is split into linker sections and emitted as one `.bin` per section.
- The packager may combine multiple small linker code sections into one 4 KB load page.
- One fixed application page is reserved for:
  - application stack
  - application writable data
  - application dispatch or jump table
- The OS image itself follows the same sectioning rules, but its runtime layout is fixed and does not need post-load relocation.

## z88dk Relocation Formats

There are two different relocation-related outputs in z88dk, and they should not be confused.

### `-reloc-info` loader relocation file

This is what the current build emits. It creates a separate `.reloc` file next to each section `.bin`.

Observed current format:

- The file is a flat array of 16-bit little-endian offsets.
- Each offset points to the first byte of a 16-bit absolute address operand inside the section binary.
- The loader reads the word at that offset and adds a relocation delta.

Confirmed examples from the current build:

- `firmware_code_crt_init.reloc = 06 00`
  - this matches `call _main` at offset `0x0005` in the section binary
  - the relocatable 16-bit operand starts at offset `0x0006`
- `firmware_code_compiler.reloc = 16 00`
  - this matches `call _Stream_Construct` at offset `0x0015`
  - the relocatable operand starts at offset `0x0016`
- `firmware_sys.reloc` is empty
  - no absolute cross-section addresses were emitted in that section

So for the current `-reloc-info` flow, the loader algorithm per section is simply:

```text
delta = actual_load_base - linked_base

for each 16-bit little-endian offset reloc_off in reloc_file:
    old_value = read_u16(section_bin, reloc_off)
    new_value = old_value + delta
    write_u16(section_bin, reloc_off, new_value)
```

## Important Constraint

Direct cross-section calls only work safely if all sections preserve the same linked relative layout, or if all such calls are redirected through a fixed dispatch page.

That means:

- intra-section absolute references can be fixed with a section-local relocation delta
- cross-section references should eventually go through dispatch stubs in a fixed page

For now, the packaging format should preserve enough metadata for the loader to:

- place each section
- relocate each section
- patch dispatch entries from exported symbol addresses

## Logical Sections vs Load Pages

The packager should distinguish between:

- logical sections
  - the linker sections emitted by z88dk and referenced in the map file
  - examples: `code_ui`, `code_fs`, `sys`, `dispatch`
- load pages
  - the actual 4 KB MMU pages the loader allocates and fills

This distinction matters because the linker may emit many small logical code sections, but the machine only has a small number of simultaneously visible MMU pages.

The packager should therefore be allowed to place multiple logical sections into a single physical load page, provided they are compatible.

Required per-logical-section metadata:

- original section name
- linked base
- actual payload size
- assigned load page index within the package
- offset within that load page
- relocation payload
- exported symbol offsets

Required per-load-page metadata:

- page type
- page flags
- total used bytes
- contained logical section list

## Section Naming Convention

The packager should classify sections by name prefix. This avoids storing too much policy in every individual build file.

### Code sections

- `code_*`
  - one code page per section
  - executable
  - usually relocatable for applications

Examples:

- `code_main`
- `code_fs`
- `code_ui`
- `code_crt_init`

### Fixed low-memory OS sections

- `rst_*`
- `bios_*`
- `os_fixed_*`

These are intended for the fixed OS layout, such as page 0 or other permanently mapped pages.

These should normally not be co-packed with relocatable application code pages.

### Dispatch section

- `dispatch`
- `dispatch_*`

This section is special:

- it lives in a page that is always mapped for the current program
- it contains stub entries, typically `JP target`
- the loader patches these entries after all code sections are placed

Note: `dispatch.asm` is a build-time source file. At runtime, the loader cares about the assembled dispatch section binary and its exported entry layout, not the `.asm` source text.

### Data sections

- `data_*`
- `rodata_*`
- `bss_*`

For application packaging, all of these should be grouped into the single fixed application data page, unless a later format revision explicitly supports multiple data pages.

Recommended grouping rule for now:

- combine all `data_*`, `rodata_*`, and `bss_*` sections into one logical package section named `app_data`
- layout order inside that page:
  - initialized data
  - read-only data copied as needed
  - zero-filled bss region
  - stack reservation
  - dispatch table reservation if it is not a separate fixed page

## Packing Policy

The packager should try to fill 4 KB code pages as much as practical.

That is the right goal because the machine only exposes a limited number of MMU pages at once, and some of those pages are permanently reserved.

Recommended first policy:

- keep fixed OS sections separate from relocatable application sections
- keep the dispatch page separate
- merge all data-like sections into one fixed application data page
- pack relocatable code sections into as few 4 KB code pages as possible

Recommended first-fit strategy:

1. Sort relocatable code sections by descending size.
2. Place each section into the first existing code page with enough free space.
3. If none fits, open a new code page.

This is simple, deterministic, and usually good enough. A more advanced bin-packing heuristic can be added later if needed.

When multiple logical sections are packed into one physical code page:

- each section gets a page-relative start offset
- the section's `.bin` is copied into the page at that offset
- each reloc offset in that section's `.reloc` file must be rebased by the section start offset
- each exported symbol offset must also be rebased by the section start offset

So the page-level relocation process becomes:

```text
for each logical section packed into page:
    page_section_base = page_load_base + section.page_offset
    delta = page_section_base - section.linked_base

    for each reloc_off in section.reloc:
        patch_at = section.page_offset + reloc_off
        old_value = read_u16(page_image, patch_at)
        new_value = old_value + delta
        write_u16(page_image, patch_at, new_value)
```

This lets the packager keep the linker section model while still using physical pages efficiently.

For the runtime package, the packager should then flatten those rebased section reloc lists into one unified page-local relocation list.

That means the final packaged load page can contain:

- one 4 KB page image
- one relocation count
- one sorted list of 16-bit offsets into that page image

So the loader only sees page-level relocation data:

```text
page_delta = actual_page_base - linked_page_base

for each reloc_off in page.reloc_list:
    old_value = read_u16(page_image, reloc_off)
    new_value = old_value + page_delta
    write_u16(page_image, reloc_off, new_value)
```

This is preferable for the loader because it is smaller, simpler, and faster than processing a per-section hierarchy at runtime.

## Dispatch Table Entries vs Reloc Entries

Dispatch entry ordering should **not** be generated from `.reloc` ordering.

These are different things:

- the `.reloc` list is a list of patch sites inside machine code
- the dispatch table is an exported call interface

The `.reloc` list says nothing about:

- which symbol a call is intended to reach at the API level
- which functions should appear in the dispatch page
- what order dispatch entries should appear in
- whether a reloc entry belongs to an internal call, a data pointer, or a dispatch call

So the dispatch table must have its own explicit ordering rule.

Recommended rule for the first version:

- generate dispatch entries in a deterministic manifest order
- for example: by section name, then by exported symbol name

That makes the dispatch page stable across builds unless symbols are added, removed, or renamed.

Even better long-term:

- define an explicit exported API list per module
- generate dispatch entries from that API list, not from all public symbols

However, this ordering rule is only for build-time generation of the dispatch section.

The loader should not depend on symbol names or export ordering at runtime.

## Runtime Dispatch Patch Table

The dispatch section should be fixed for the lifetime of the loaded program.

That means:

- code pages may move when the program is loaded
- exported functions end up at new runtime addresses
- the dispatch page remains at a known fixed page for that program
- the loader patches each dispatch stub to jump to the final runtime address of its target function

So the loader does **not** infer dispatch targets from `.reloc` order.

Instead, the package should contain an explicit dispatch patch table.

Recommended compact runtime entry format:

```text
Offset  Size  Field
0x00    2     Dispatch stub offset within dispatch page
0x02    2     Target load page index
0x04    2     Target offset within target load page
```

The loader then does:

```text
stub_addr   = dispatch_page_base + stub_offset
target_addr = loaded_page_base[target_page_index] + target_offset

write_u16(dispatch_page, stub_offset + 1, target_addr)
```

This assumes each stub is encoded as `JP nn`, so the 16-bit operand begins at `stub_offset + 1`.

This is simpler than using names at runtime and avoids any dependency on symbol tables inside the loader.

## What Reloc Will Do Once Calls Target Dispatch

If the compiler or linker resolves cross-page calls to dispatch stub symbols instead of direct target symbols, then:

- the caller section's `.reloc` file will still contain patch sites for the `CALL dispatch_*` address operands
- the dispatch page may also have its own relocation or patch points for the `JP real_target` operands

But the dispatch page should not be rebuilt by interpreting reloc offsets in order.

Instead, the loader should patch dispatch entries by explicit symbol mapping:

```text
dispatch stub "dispatch_Stream_Read" -> actual address of "_Stream_Read"
dispatch stub "dispatch_Stream_Write" -> actual address of "_Stream_Write"
```

At build time, that mapping comes from manifest export data and dispatch-entry metadata, not from reloc-entry sequence.

At runtime, the loader should use only the compact dispatch patch table, not symbol names.

## Proposed Package Layers

There should be two layers:

### 1. Build manifest

This is a build artifact for inspection and debugging.

Current file:

- `.build/firmware.manifest.json`

It already records, per section:

- linked base
- true size
- bin file name and size
- reloc file name and size
- exported symbols with section-relative offsets

### 2. Final packaged program file

This is the file the OS loader reads.

Suggested extension:

- `.zpk`

The packager should consume:

- per-section `.bin`
- per-section `.reloc`
- manifest metadata

And emit one compact binary container.

The packager should also transform:

- per-section reloc lists into unified page-level reloc lists
- symbol-name-based dispatch information into a compact dispatch patch table

## Proposed Binary Container Format

### File header

All values little-endian.

```text
Offset  Size  Field
0x00    4     Magic = 'ZPK1'
0x04    2     Format version = 0x0001
0x06    2     Header size
0x08    2     Section count
0x0A    2     Flags
0x0C    4     Section table offset
0x10    4     String table offset
0x14    4     Blob data offset
0x18    4     Entry section index
0x1C    2     Entry offset within section
0x1E    2     Reserved
```

### Section table entry

One entry per packaged logical section or load page, depending on the chosen package layout.

If logical sections are packed into shared code pages, the package should contain:

- a load-page table
- a logical-section table

The logical-section table points into a containing load page and gives the section's offset within that page.

```text
Offset  Size  Field
0x00    2     Section type
0x02    2     Section flags
0x04    2     Name offset in string table
0x06    2     Reserved
0x08    2     Linked base
0x0A    2     In-memory size
0x0C    2     Page size
0x0E    2     Export count
0x10    4     Bin blob offset
0x14    2     Bin blob size
0x16    2     Reloc count
0x18    4     Reloc blob offset
0x1C    2     Reloc blob size
0x1E    2     Export table offset relative to blob area
```

For the runtime package, a load-page record is more useful than a raw logical-section record.

Recommended load-page record fields:

```text
Offset  Size  Field
0x00    2     Page type
0x02    2     Page flags
0x04    2     Linked page base
0x06    2     Used bytes in page
0x08    2     Reloc count
0x0A    2     Dispatch patch count
0x0C    4     Page image blob offset
0x10    4     Reloc blob offset
0x14    4     Dispatch patch blob offset
```

Logical-section records can still exist for debugging or optional loader introspection, but the loader's hot path should be page-oriented.

### Section type values

```text
0 = unused
1 = fixed OS code
2 = relocatable application code
3 = fixed dispatch page
4 = combined application data page
5 = fixed OS data
```

### Section flags

```text
bit 0 = readable
bit 1 = writable
bit 2 = executable
bit 3 = relocatable
bit 4 = zero-fill tail present
bit 5 = fixed-placement required
```

### Export table entry

This is loader-facing metadata used to patch the dispatch page.

```text
Offset  Size  Field
0x00    2     Name offset in string table
0x02    2     Offset within section
```

The loader computes:

```text
actual_export_address = actual_section_base + export.offset
```

## Loader Flow For The Proposed Format

1. Read file header.
2. Read load-page table.
3. Allocate pages according to page type and flags.
4. Copy each packaged load page image into its destination page.
5. Apply the page-local relocation list.
6. Patch the fixed dispatch page using the compact dispatch patch table.
7. Zero any declared BSS tail in the combined data page.
8. Jump to the declared entry point.

## What The Packager Should Do

The packager is responsible for translating loose build outputs into the final loader format.

Inputs:

- `*.bin`
- `*.reloc`
- `*.manifest.json`

Outputs:

- one `.zpk` package file

Packager responsibilities:

- classify sections by naming convention
- merge all data-like sections into one logical data page
- pack compatible code sections into as few 4 KB pages as practical
- convert section `.reloc` files into unified page-level relocation lists
- emit compact dispatch patch tables for the loader
- emit logical-section to load-page placement metadata
- choose or record the entry section and offset

## Recommended First Implementation

Keep the first packager version intentionally simple.

- Keep JSON manifest generation for debugging.
- Add one binary package file beside it.
- Do not try to embed `dispatch.asm` source.
- Treat the assembled dispatch section as just another fixed section.
- Make the loader runtime format page-oriented, not symbol-oriented.
- For now, only support:
  - fixed OS sections
  - relocatable code sections
  - one combined application data section

That is enough to get the loader, the build, and the package format aligned without over-designing the first revision.
