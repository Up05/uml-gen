# UML Activity Diagram Generator

Takes in simple formatted text. Draws UML diagrams.

Mainly in Lithuanian language, but I mean, English is supported... (Also Portuguese)

## Usage

https://github.com/user-attachments/assets/0c0504e4-2391-4a3d-ab4e-6e24c3ce0134


Run the program. Edit the `scenarijus.txt` file. The program will update the diagram automatically.

Zoom in, center the diagram on screen manually and press `Enter`.

## The format

```
# Comments, i.e.: text that gets ignored by the program
```

```
KEY=text

# builtin keys: NAUDOTOJAS, PAGRINDINIS, ALTERNATYVOS
```

```
[1.a.1.a. text text text

# List numbering, these start with `[` and end with ` ` (whitespace).
```

```
[1.1. text text text {condition for the branch, i.e.: text on arrow}

# These go after list items and are just there for the rhombus text conditions.
```

```
| Swim | lanes |

# separate the screen into user parts, swimlanes have to start and end with the `|`
# or they will need be considered swim lanes
```


Btw, generally, new lines and whitespace does not matter here.

## Installation

If you are on Windows and manage to setup msvc trash + a debugger, you can build it and then debug the crash that happens.

If you are on Linux, just grab odin-lang whichever way you like.  
Grab this code, via: `git clone https://github.com/Up05/uml-gen`,  
and `odin build .`

## Configuration

I wanted to add sliders, but couldn't be bothered, so there is a struct at the beggining of the program
where you can set various diagram drawing values.


