package main

import "core:fmt"

import "core:math/rand"
import "core:container/small_array"

Node :: struct {
    name: string,
    cond: string,
    steps: [dynamic] Node,
    pos: vec,
    offset: vec,
    id: u64
}

Scenario :: struct {
    name: string,
    user: string,
    main: Node,
}

sc: Scenario

// Should only contain slices
tokens: [dynamic] string

realline := 1 // for skipping
fakeline := 1 // for peeking
curr := 0

peek :: proc(o := 0) -> string {
    if curr >= len(tokens) - 1 do return ""
    o := o
    fakeline = realline
    for t in tokens[curr:] {
        if t == "\n" do fakeline += 1
        else {
            if o == 0 do return t
            o -= 1
        }
    }
    return ""
}

skip :: proc(n := 1) -> bool {
    n := n
    for t in tokens[curr:] {
        if t == "\n" { realline += 1; fakeline = realline }
        else {
            if n == 0 do return true
            n -= 1
        }
        curr += 1
    }
    return false // value here does not really matter
}

next :: proc() -> string {
    token := peek(0)
    skip(1)
    return token
}


parse :: proc(raw: string) {
    clear(&tokens)
    tokenize(raw)

    fmt.println()
    fmt.println("==================================================================")
    fmt.println()

    fmt.printf("%#v\n", tokens)

    fmt.println()
    fmt.println("==================================================================")
    fmt.println()

    sc = {}
    sc.main.name = "/root"
    curr = 0
    realline = 0
    fakeline = 0

    for peek() != "" {
        if !parse_assign() do skip()
    }

    // fmt.println(sc)
    print_scenario(sc)
}

parse_assign :: proc() -> bool {
    switch(peek()) {
    case "PAVADINIMAS":
        if peek(1) != "=" {
            error = "Keista, tekste yra PAVADINIMAS, bet po žodžio nėra lygybės ženklo... Ar tikrai to norėjote?"
            return false
        }
        skip(2)
    
        sc.name = next()
        return true

    case "NAUDOTOJAS": 
        if peek(1) != "=" {
            error = "Keista, tekste yra NAUDOTOJAS, bet po žodžio nėra lygybės ženklo... Ar tikrai to norėjote?"
            return false
        }
        skip(2)

        sc.user = next()
        return true

    case "PAGRINDINIS": 
        if peek(1) != "=" {
            error = "Keista, tekste yra PAGRINDINIS, bet po žodžio nėra lygybės ženklo... Ar tikrai to norėjote?"
            return false
        }
        skip(2)
        
        for parse_list_item(&sc.main) {}
        return true

    case "ALTERNATYVOS":
        if peek(1) != "=" {
            error = "Keista, tekste yra ALTERNATYVOS, bet po žodžio nėra lygybės ženklo... Ar tikrai to norėjote?"
            return false
        }
        skip(2)

    
        for parse_list_item(&sc.main) {}
        return true

    }
    
    return false
}

parse_list_item :: proc(node: ^Node) -> bool {
    node := node
    item := peek()
    if len(item) < 4 || item[0] != '[' do return false

    the_line := fakeline;   skip() // '[1.a. '

    path := item[1:] // 1.a.1.a. ...

    index: int
    for len(path) > 0 {
        if path[0] == '.' || path[0] == ')' || path[0] == ' ' {
            
            if index >= len(node.steps) {
                if index > len(node.steps) {
                    error = "Skaičiukas sąraše yra per didelis"
                    emore = caprintf("Anksčiau buvo tik %d, o dabar jau naudojamas %d. Eilutė: %d", len(node.steps), index + 1, the_line)
                }
                for index >= len(node.steps) {
                    fmt.println("ADDED NEW NODE!", index, len(node.steps))
                    append(&node.steps, Node { name = "<Neužvardintas>" })
                }
                node = &node.steps[index]
            } else {
                node = &node.steps[index]
            }
    
            index = 0
            if (len(path) > 0 && path[0] == ' ') || (len(path) > 1 && path[1] == ' ') do break
            path = path[1:]
            continue
        }

        numbering : u8 = '1' if (path[0] >= '1' && path[0] <= '9') else 'a' if (path[0] >= 'a' && path[0] <= 'z') else 0
    
        if numbering == 0 {
            error = "Sąrašo skaičių maišale yra blogas ženklas! Galimi tik: skaičiai, mažosios raidės, taškai! (Ir padžioje: [, o gale tarpas)" 
            emore = caprintf("Blogas simbolis: '%c' / 0x'%x', eilutė: %d", path[0], path[0], the_line) 
            path = path[1:]
            continue
        }

        index *= 10
        index += auto_cast (path[0] - numbering)
        path = path[1:]
    }

    node.name = next()
    node.id = rand.uint64()
    
    if len(peek()) > 0 && peek()[0] == '{' {
        node.cond = next()
        node.cond = node.cond[1:len(node.cond)-1]
    }

    return true
}


tokenize :: proc(raw: string) {

    text_start: int

    line: int = 1
    skip: int
    main: for r, i in raw {
        this := raw[i:]

        if skip > 0 {
            skip -= 1
            continue
        }

        if key, any := which_prefix(this, "PAVADINIMAS", "NAUDOTOJAS", "PAGRINDINIS", "ALTERNATYVOS"); any {

            for r2, j in this {
                if r2 == ' ' || r2 == '\n' || r2 == '\t' do continue
                if r2 == '=' {
                    if text_start != i do append(&tokens, raw[text_start:i])
                    append(&tokens, raw[i:i + j])
                    fmt.println(raw[text_start:i + j + 1])
                    text_start = i + j + 1
                    skip += j

                    append(&tokens, this[j:j + 1])
                    continue main
                }
            }
        
        }

        if starts_with(this, "\r\n") {
            if text_start != i do append(&tokens, raw[text_start:i])
            text_start = i + 2
            append(&tokens, this[1:2])
            skip += 1
            line += 1
        }

        switch r {
        case '#':
            if text_start != i do append(&tokens, raw[text_start:i])
            end, end_u8 := runes_until(this, '\n')
            text_start = i + end_u8
            skip += end

        case '=':
            error = "Prieš lygybės ženklą turi eiti vienas iš raktų: PAVADINIMAS, NAUDOTOJAS, PAGRINDINIS, ALTERNATYVOS"       
            emore = caprintf("Eilutė: %d", line)

        case '[':
            end, end_u8 := runes_until(this, ' ')
            if end == -1 {
                error = "[1.a.  turi pasibaigti tarpo simboliu, bet jo trūksta!"   
                emore = caprintf("Užtat yra: %s...", this[:min(len(this), 7)])
                break
            }

            if text_start != i do append(&tokens, raw[text_start:i])
            append(&tokens, raw[i:i + end_u8 + 1])
            text_start = i + end_u8 + 1
            skip += end

        case '{':
            end, end_u8 := runes_until(this, '}')
            if end == -1 {
                error = "{...  turi pasibaigti '}' simboliu, bet jo trūksta!"   
                emore = caprintf("Užtat yra: %s...", this[:min(len(this), 7)])
                break
            }

            if text_start != i do append(&tokens, raw[text_start:i])
            append(&tokens, raw[i:i + end_u8 + 1])
            text_start = i + end_u8 + 1
            skip += end

        case '\n':
            if text_start != i do append(&tokens, raw[text_start:i])
            text_start = i + 1
            append(&tokens, this[:1])
            line += 1
            
        }
    }

    if text_start != len(raw) do append(&tokens, raw[text_start:])

}
