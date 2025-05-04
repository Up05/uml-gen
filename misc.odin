package main

import "core:fmt"

eat_err :: proc(v: $T, err: $E) -> T {
    return v
}

first_rune :: proc "contextless" (s: string) -> rune {
    for r in s do return r
    return 0
}

runes_until :: proc(haybale: string, needle: rune) -> (runes, bytes: int) {
    for r, i in haybale {
        if r == needle do return runes, i
        runes += 1
    }
    return -1, -1
}

which_one :: proc(a: $T, B: ..T) -> (res: T, any: bool) {
    for b in B {
        if a == b do return b, true
    }
    return {}, false
}

starts_with :: proc(a, b: string) -> bool {
    return len(a) >= len(b) && a[:len(b)] == b
}

which_prefix :: proc(a: string, B: ..string) -> (res: string, any: bool) {
    for b in B {
        if starts_with(a, b) do return b, true
    }
    return {}, false
}



any_of :: proc(a: $T, B: ..T) -> bool {
    for b in B {
        if a == b do return true
    }
    return false
}

rune_size :: proc "contextless" (r: rune) -> int {
	switch {
	case r < 0:             return -1
	case r <= 1<<7  - 1:    return 1
	case r <= 1<<11 - 1:    return 2
	case r <= 1<<16 - 1:    return 3
	case r <= '\U0010ffff': return 4
	}
	return -1
}

print_scenario :: proc(sc: Scenario) {
    print_nodes :: proc(nodes: [dynamic] Node, level := 0) {
        PAD := "                                                                "
        for n in nodes {
            fmt.printfln("%s - %s:", PAD[:level * 4], n.name)
            print_nodes(n.steps, level + 1)
        }
    }
    
    fmt.println("----------------------------------------")
    fmt.printfln("Pavadinimas: %s", sc.name)
    fmt.printfln("Naudotojas: %s", sc.user)
        
    print_nodes(sc.main.steps)

    fmt.println("----------------------------------------")

}

find_space_from :: proc(str: string, offset: int) -> int {
    if offset >= len(str) do return len(str)
    for r, i in str[offset:] {
        if r == ' ' do return i + offset
    }
    return len(str)
}

intersects :: proc(a, b, b_size: vec) -> bool {
    return a.x >= b.x && a.y >= b.y && a.x <= b.x + b_size.x && a.y <= b.y + b_size.y
}

avg :: proc(a, b: f32) -> f32 {
    return (a + b) / 2
}



