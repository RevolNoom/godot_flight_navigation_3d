---
description: Use when write or edit a rule file.
# Instructions must not state the defaults, nor alternatives on instruction fail: Prevent useless instructions.
---

# Rule writings

## YAML frontmatter header
`paths:` globs MUST exist. If it does not, stop, and then request the user for paths or file type in natural language, and converts that to globs before writing the rule.
`description:` must NOT exist in a rule file. This ban applies to rule files only, not to commands or skills.

## Explanation goes to comments in YAML frontmatter. Comments are separated by blank lines
✅
\---
\# Functions must have an explicit return type to help with type checking and makes the code more readable.
\#
\# Instructions must not state the defaults, nor alternatives on instruction fail: Prevent useless instructions.
\---

## Instructions use example when it is something to follow

## Instructions only use counter-example when it is something to avoid

## File name format: <language>[-<type> ...].md
`<language>` is the file's language extension.
`<type>` is free-form. Use as many `-<type>` segments as needed to narrow the scope.
✅
gd.md
gd-enum.md
cs-test-controller.md

## Instruction is on one header

## Instructions must be short, easily verifiable
\# Functions must have an explicit return type

## Instructions must name the exact structure to follow
\# Functions must have an explicit return type
```gdscript
def get_user(id: int) -> User:
  ...
```

## Instructions must not contain explanation
❌
\# Functions must have an explicit return type
```gdscript
def get_user(id: int) -> User:
  ...
```
This is important because it helps with type checking and makes the code more readable.

## Instructions must not state the defaults, nor alternatives on instruction fail
❌
\# Use `Grep` for text that is not a symbol
```
Grep(pattern: "TODO: voxelize", glob: "**/*.gd")
```
