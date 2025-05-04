package main

import "core:os/os2"
import "core:time"
import "core:mem"
import "core:strings"
import "core:math"

import "core:fmt"
import rl "vendor:raylib"

vec  :: rl.Vector2
cstr :: strings.clone_to_cstring

BG   :: rl.Color { 200, 200, 200, 255 }

file_in  : string  // dažniausia, (PROGRAMOS APLANKALAS)/scenarijus.txt
file_out : string  // nebenaudojamas

error    : cstring
emore    : cstring

width    : i32
height   : i32
font     : rl.Font
camera   : rl.Camera2D = { zoom = 1 }
panning  : u64

arrow_start : vec

buffer_alloc : mem.Allocator

Options :: struct {
    font_sz : i32,
    node_w  : f32,
    node_h  : f32,
    padding : f32,
    arrow_h : f32,
    arrow_V : f32, // kiek strėlytės viršus bus įkritęs... tipo: v = 0.1 ar ⮟ = 0.75 ar ▼ = 1
}

opts := Options {
    font_sz = 12,
    node_w  = 160,
    node_h  = 60,
    padding = 80,
    arrow_h = 10,
    arrow_V = 0.9
}

caprintf :: proc(format: string, args: ..any) -> cstring {
    delete(emore)
    return fmt.caprintf(format, ..args, allocator = context.allocator)
}

main :: proc() {
    file_err_msg :: proc(file: string) -> cstring {
        return caprintf("Failo vieta: %s", eat_err(os2.get_absolute_path(file, context.temp_allocator)))
    }

    using opts

    // ============ PROGRAMOS PRADŽIA ============ 
    
    self_dir, err_self := os2.get_executable_directory(context.allocator)
    assert(err_self == nil, "Neišėjo surasti pačios programos failo katalogo. Neturiu kur ieškoti scenarijus.txt!")
    os2.set_working_directory(self_dir)
    if len(os2.args) < 2 {
        fmt.println("Naudojimas: uml-gen [FAILAS]\nPvz.: ./uml-gen.exe scenarijus.txt")
        file_in = "scenarijus.txt"
    } else {
        file_in = os2.args[1]
    }

    buffer_arena: mem.Arena
    mem.arena_init(&buffer_arena, make([] u8, 16 * 1024 * 1024))
    buffer_alloc = mem.arena_allocator(&buffer_arena)

    emore = fmt.caprint("") // just in case nil pointer freeing is bad in odin
    
    // ============  LANGO SUKŪRIMAS  ============ 

    rl.SetTraceLogLevel(.ERROR)
    rl.SetConfigFlags({ .WINDOW_RESIZABLE, .MSAA_4X_HINT })
    rl.InitWindow(1280, 720, "UML Generatorius")
    rl.SetTargetFPS(60)

    font = rl.LoadFontEx("Helvetica.ttf", font_sz * 2, nil, 0x1FFF)
    
    pwidth: i32
    last_modified: time.Time

    for !rl.WindowShouldClose() {

        // ============   KAMERA IR LANGAS   ============ 

        width  = rl.GetScreenWidth(); defer pwidth = width
        height = rl.GetScreenHeight()
        
        if pwidth != width do camera.target = { f32(width)/8, f32(height)/8 }
        camera.offset = { f32(width)/2, f32(height)/2 }
        
        if rl.IsMouseButtonUp(.LEFT) do panning = 0

        defer if rl.IsMouseButtonDown(.LEFT) {
            if panning == 0 {
                mouse_dt := rl.GetMouseDelta()
                camera.target -= mouse_dt
            } 
        }

        camera.zoom = math.exp_f32(math.log_f32(camera.zoom, math.E) + (cast (f32) rl.GetMouseWheelMove() * 0.1));

        // ============ PAGRINDINIS PIEŠIMAS ============ 

        rl.BeginDrawing() 
        defer rl.EndDrawing()
        rl.ClearBackground({ 200, 200, 200, 255 })
        
        defer {
            if rl.IsKeyDown(.ENTER) {
                folder, _ := os2.get_absolute_path(".", context.temp_allocator)
                files, err := os2.read_all_directory_by_path(folder, context.temp_allocator)
                if err != nil {
                    error = "Neišėjo perskaityti aplankalo su programa!"
                    emore = caprintf("Katalogas: %s", folder)
                } else {
                    diagram_count := 1
                    for file in files {
                        if base, ext := os2.split_filename_all(file.name); ext == "png" {
                            diagram_count += 1
                        }
                    }

                    rl.TakeScreenshot(caprintf("diagrama-%d.png", diagram_count))
                }
            }

            rl.DrawTextEx(font, "Paspauskite Enter padaryti ekrano nuotraukai", { 4, 2 }, 24, 1, rl.GRAY)
            rl.DrawTextEx(font, error, { 4, 26*1 }, 24, 1, { 127, 0, 0, 255 })
            rl.DrawTextEx(font, emore, { 4, 26*2 }, 24, 1, { 0, 0, 127, 255 })
        
        }

        rl.BeginMode2D(camera)
        defer rl.EndMode2D()

        defer redraw()
        
        // ============ FAILO SINCHRONIZACIJA ============ 

        change_time, err_stat := os2.last_write_time_by_name(file_in)
        if err_stat != nil { 
            error = "Neišėjo gauti įvesties failo pakeitimo datos..." 
            emore = file_err_msg(file_in)
            continue
        }

        if time.diff(last_modified, change_time) > 0 {
            free_all(buffer_alloc)
            data, read_err := os2.read_entire_file_from_path(file_in, buffer_alloc)
            if read_err != nil {
                error = "Neišėjo perskaityti įvesties failo"
                emore = file_err_msg(file_in)
            }
            parse(string(data))
            last_modified = change_time
        }

        // =============================================== 

        free_all(context.temp_allocator)
    }

}

redraw :: proc() {
    using opts

    arrow_start = {}

    tree_start: vec = { 0, 0 }
    
    { // starting point
        pos := tree_start - { -node_w / 2, padding + node_h/2.5 }
        rl.DrawCircleV(pos, node_h / 2.5, rl.BLACK)
        arrow(pos + { -node_w / 2 + node_w / 2, node_h / 2.5 }, tree_start + { node_w / 2, 0 }, "")
    }

    draw_node(&sc.main, tree_start)

}

depth :: proc(node: Node) -> int {
    
    sum: int
    for c in node.steps {
        sum = max(sum, depth(c))
    }
    return 1 + sum
}

arrow :: proc(a: vec, b: vec, text: string, horizontal := false) {
    using opts
    
    // rl.DrawCircleV(a, 3, rl.RED)
    // rl.DrawCircleV(b, 3, rl.BLUE)

    if math.abs(a.x - b.x) < 2 { // plius minus lygūs
        rl.DrawLineV(a, b, rl.BLACK)
        rl.DrawTriangle(b - { 0, arrow_h * arrow_V }, b, b - { -arrow_h/2, arrow_h }, rl.BLACK)
        rl.DrawTriangle(b - { +arrow_h/2, arrow_h }, b, b - { 0, arrow_h * arrow_V }, rl.BLACK)
        // čia man nereikia teksto

    } else if math.abs(a.y - b.y) < 2 {
        rl.DrawLineV(a, b, rl.BLACK)

        d := math.sign(a.x - b.x) // direction
        rl.DrawTriangle(b + { arrow_h * arrow_V, 0 } * d, b, b + { arrow_h, +arrow_h/2 } * d, rl.BLACK)
        rl.DrawTriangle(b + { arrow_h, -arrow_h/2 } * d, b, b + { arrow_h * arrow_V, 0 } * d, rl.BLACK)
        
        if text != "" {
            draw_wrapped_text(
                text,
                { min(a.x, b.x), a.y - f32(font_sz) * 1.5 }, 
                { max(a.x, b.x) - min(a.x, b.x), f32(font_sz)*2 },
                BG
            )
        }

    } else {
        
        dx := math.sign(a.x - b.x) // direction
        dy := math.sign(a.y - b.y) // direction

        Y1 := min(a.y, b.y) if dy < 0 else max(a.y, b.y)
        Y2 := max(a.y, b.y) if dy < 0 else min(a.y, b.y)
        X1 := min(a.x, b.x) if dx > 0 else max(a.x, b.x)
        X2 := max(a.x, b.x) if dx > 0 else min(a.x, b.x)

    
        if horizontal {
        
            rl.DrawLineV({ X1, Y2 }, { avg(X1, X2), Y2 }, rl.BLACK)
            rl.DrawLineV({ avg(X1, X2), Y1}, { avg(X1, X2), Y2 }, rl.BLACK)
            rl.DrawLineV({ avg(X1, X2), Y1 }, { X2, Y1 }, rl.BLACK)

            rl.DrawTriangle(b + { arrow_h * arrow_V, 0 } * dx, b, b + { arrow_h, +arrow_h/2 } * dx, rl.BLACK)
            rl.DrawTriangle(b + { arrow_h, -arrow_h/2 } * dx, b, b + { arrow_h * arrow_V, 0 } * dx, rl.BLACK)

        } else {

            rl.DrawLineV({ X2, Y1 }, { X2, avg(Y1, Y2) }, rl.BLACK)
            rl.DrawLineV({ X1, avg(Y1, Y2) }, { X2, avg(Y1, Y2) }, rl.BLACK)
            rl.DrawLineV({ X1, avg(Y1, Y2) }, { X1, Y2 }, rl.BLACK)

            rl.DrawTriangle(b - { 0, arrow_h * arrow_V }, b, b - { -arrow_h/2, arrow_h }, rl.BLACK)
            rl.DrawTriangle(b - { +arrow_h/2, arrow_h }, b, b - { 0, arrow_h * arrow_V }, rl.BLACK)
        }

        if text != "" {
            draw_wrapped_text(
                text,
                { min(a.x, b.x), min(a.y, b.y) }, 
                { max(a.x, b.x) - min(a.x, b.x), max(a.y, b.y) - min(a.y, b.y) },
                BG
            )
        }

    }}

// Čia logikai skyriau visą rytą, galit net nebandyt iš narpliot,
// dabar jau niekas to nesugebės...
draw_node :: proc(node: ^Node, pos: vec) {
    using opts
    pos := pos
    
    offset_sum  : vec

    for &child, i in node.steps {

        fuck_it: bool

        offset_sum += child.offset
        pos += child.offset // !!!!
        
        d := depth(child)
        switch d {
        case 1:
            draw_node(&child, pos)   

        case 2:
            
            rhombus := pos - offset_sum + (0 if i == 0 else node.steps[i - 1].offset) + { node_w/2, node_h/2 }

            if i > 0 do arrow(arrow_start, rhombus + { 0, -node_h/2 }, "")
            rl.DrawPolyLines(rhombus, 4, node_h/2, 90, rl.BLACK)
            arrow_start = rhombus - { node_h/2, 0 }
            draw_node(&child, pos - offset_sum - { padding * 3, 0 })    
            arrow_start = rhombus + { node_h/2, 0 }

            fuck_it = true

            pos.x += padding*3

        case 3:
            error = "Tingėjau pridėti daugiau lygių"
            emore = "Tiesiog turėkit dviejų lygių sąrašus: 1.a., o ne, pvz.: 1.a.2."

        }

        child.pos = pos
        
        if !fuck_it && i == 0 && arrow_start != {} {
            arrow(arrow_start, pos + { node_w, node_h/2 }, child.cond, true)
            arrow_start = {}
        }
        if fuck_it && arrow_start != {} {
            arrow(arrow_start, pos + { 0, node_h/2 }, child.cond, true)
            arrow_start = {}
        }

        if rl.IsMouseButtonPressed(.LEFT) && intersects(rl.GetScreenToWorld2D(rl.GetMousePosition(), camera), pos, { node_w, node_h }) {
            panning = child.id
        }

        if child.id == panning {
            child.offset += rl.GetMouseDelta()
        }

        if intersects(rl.GetScreenToWorld2D(rl.GetMousePosition(), camera), pos, { node_w, node_h }) {
            rl.DrawRectangleV(pos, { node_w, node_h }, rl.GRAY)
            // rl.DrawCircleV(rl.GetScreenToWorld2D(rl.GetMousePosition(), camera), 15, rl.BLUE)
        }
        // arrow(pos + { node_w / 2, node_h }, pos + { node_w / 2, node_h + padding }, "")
        if i != 0 && d == 1 do arrow(node.steps[i - 1].pos + { node_w / 2, node_h }, pos + { node_w / 2, 0 }, "")
        else if i == 0 && arrow_start != {} do arrow(arrow_start, { pos.x, arrow_start.y }, "")
        arrow_start = child.pos + { node_w / 2, node_h }

        rl.DrawRectangleRoundedLines({ pos.x, pos.y, node_w, node_h }, 0.3, 10, rl.BLACK)
        // rl.DrawTextEx(font, cstr(child.name, context.temp_allocator), pos + { 2, 4 }, 12, 1, rl.BLACK)
        draw_wrapped_text(child.name, pos + { 2, 4 }, { node_w, node_h })

        pos.y += node_h + padding
    
        if i == len(node.steps) - 1 {
            arrow(arrow_start, { arrow_start.x, pos.y }, "")
            rl.DrawCircleV(pos + { node_w / 2, node_h / 2.5 }, node_h / 2.5 - 5, rl.BLACK)
            rl.DrawEllipseLines(i32(pos.x + node_w / 2), i32(pos.y + node_h / 2.5), node_h / 2.5, node_h / 2.5, rl.BLACK) 
        }

    }
    
    // arrow_start = {}
}

draw_wrapped_text :: proc(text: string, pos: vec, box_size: vec, bg := rl.Color { 0, 0, 0, 0 }) {
    using opts
    text := text
    opos := pos // original pos
    pos  := pos


    lines := make([dynamic] string, context.temp_allocator)
    
    cursor: int
    pcursor: int
    for {
        cursor = find_space_from(text, cursor + 1)
        defer pcursor = cursor
        
        csel := cstr(text[:cursor], context.temp_allocator)
        size := rl.MeasureTextEx(font, csel, f32(font_sz), 1)
        
        if size.x >= box_size.x - 8 {
            append(&lines, text[:pcursor])
            text = text[pcursor + 1:]
            pcursor = 0
            cursor = 0
        }

        if cursor >= len(text) - 2 {
            append(&lines, text)
            break
        }
    }

    for line in lines {
        ctext := cstr(line, context.temp_allocator)
        size  := rl.MeasureTextEx(font, ctext, f32(font_sz), 1) 
        
        o := vec { (box_size.x - size.x) / 2, (box_size.y - (f32(size.y + 1) * f32(len(lines)))) / 2.5 }
        rl.DrawRectangleV(snap(pos + o, 2), size, bg)
        rl.DrawTextEx(font, ctext, snap(pos + o, 2) + { -0.25, -0.5 }, f32(font_sz), 1, rl.BLACK)
        pos.y += f32(font_sz) + 1
    }


}

snap :: proc(v: vec, px: int) -> vec {
    return { f32(int(v.x * f32(px)) / px), f32(int(v.y * f32(px)) / px) }

}

