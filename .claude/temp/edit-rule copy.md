---
# Add guidelines to writing effective rules. Rules specify the structure of the type of file. 
---

# Rule writings

## YAML frontmatter header
`paths:` globs MUST exist. If it does not, stop, and then request the user for paths or file type in natural language, and converts that to globs before writing the rule.
`description:` must NOT exist.
"# Comments to explain the rules to human readers."

## File name format: <language>[-<type> ...].md
gd.md
gd-enum.md
cs-test-controller.md

## Instructions must be short, easily verifiable.
Functions must have an explicit return type.

## Instructions must name the exact structure to follow
Functions must have an explicit return type. 
```gdscript
def get_user(id: int) -> User:
  ...
```

## Instructions must not contain explanation.
Functions must have an explicit return type. 
```gdscript
def get_user(id: int) -> User:
  ...
```
This is important because it helps with type checking and makes the code more readable.


## Explanation goes to comments in YAML frontmatter 
\---
\# Functions must have an explicit return type to help with type checking and makes the code more readable.
\---

## Instructions only use counter-example when it means negatively
Refers to "## Instructions must not contain explanation." section



