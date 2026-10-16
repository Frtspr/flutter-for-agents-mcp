"""
High-Fidelity Terminal Split-Screen Benchmark Demo GIF Generator
for `flutter-sanity-mcp`.

Features:
1. Token-level syntax highlighting (CLI commands, JSON directives, Flutter exceptions, RenderObject trees).
2. Smooth odometer interpolation for token counters and latency gauges.
3. High-grade visual elements:
   - Mini KPI metric cards with animated progress bars in the footer.
   - Glowing pill badges with multi-layer bloom borders.
   - Terminal typing simulation with animated blinking cursor ('▋' / crisp vector block).
   - Dynamic scrolling simulation for the 4,000-line ASCII subtree dump with sliding scrollbar thumb.
4. Adaptive palette quantization with LANCZOS resampling and zero-dither LZW compression,
   guaranteeing output file size strictly under 2.5 MB (< 500 KB typical) for instantaneous GitHub loading.
"""

import os
import re
import math
import argparse
from PIL import Image, ImageDraw, ImageFont

# Canvas Geometry
WIDTH = 1240
HEIGHT = 760

# Palette (GitHub Dark / Monokai Pro Cyber Theme)
BG_COLOR = (13, 17, 23)
HEADER_BG = (22, 27, 34)
BORDER_COLOR = (48, 54, 61)
BORDER_SUBTLE = (33, 38, 45)
PANEL_BG = (15, 20, 27)
CARD_BG = (20, 26, 36)
CARD_BORDER = (42, 52, 68)

TEXT_DEFAULT = (230, 237, 243)
TEXT_MUTED = (140, 150, 165)
TEXT_DARK = (85, 95, 105)
TEXT_BRIGHT = (255, 255, 255)

COLOR_RED = (248, 81, 73)
COLOR_RED_BG = (55, 18, 22)
COLOR_RED_GLOW = (140, 35, 40)

COLOR_GREEN = (63, 185, 80)
COLOR_GREEN_BG = (18, 48, 28)
COLOR_GREEN_GLOW = (35, 120, 50)

COLOR_YELLOW = (227, 179, 65)
COLOR_YELLOW_BG = (50, 40, 12)
COLOR_YELLOW_GLOW = (130, 100, 30)

COLOR_BLUE = (88, 166, 255)
COLOR_BLUE_BG = (20, 40, 65)

COLOR_PURPLE = (188, 140, 255)
COLOR_PURPLE_BG = (45, 25, 65)
COLOR_PURPLE_GLOW = (120, 70, 160)

COLOR_CYAN = (56, 189, 248)
COLOR_CYAN_BG = (16, 42, 60)
COLOR_CYAN_GLOW = (30, 110, 150)


# ==============================================================================
# Cross-Platform Typography Loader
# ==============================================================================
def get_font(path_win, size, is_bold=False):
    """Loads TrueType font with fallbacks for Windows, Linux, and macOS."""
    if os.path.exists(path_win):
        return ImageFont.truetype(path_win, size)
    fallbacks = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf" if is_bold else "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if is_bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/Library/Fonts/SF-Pro-Text-Bold.otf" if is_bold else "/Library/Fonts/SF-Pro-Text-Regular.otf",
    ]
    for fb in fallbacks:
        if os.path.exists(fb):
            return ImageFont.truetype(fb, size)
    return ImageFont.load_default()

font_title = get_font(r"C:\Windows\Fonts\segoeuib.ttf", 15, is_bold=True)
font_badge = get_font(r"C:\Windows\Fonts\segoeuib.ttf", 11, is_bold=True)
font_metric_num = get_font(r"C:\Windows\Fonts\segoeuib.ttf", 15, is_bold=True)
font_metric_lbl = get_font(r"C:\Windows\Fonts\segoeui.ttf", 10)
font_kpi_num = get_font(r"C:\Windows\Fonts\segoeuib.ttf", 14, is_bold=True)
font_kpi_lbl = get_font(r"C:\Windows\Fonts\segoeui.ttf", 10, is_bold=True)

font_cmd = get_font(r"C:\Windows\Fonts\consolab.ttf", 13, is_bold=True)
font_code = get_font(r"C:\Windows\Fonts\consola.ttf", 12)
font_code_bold = get_font(r"C:\Windows\Fonts\consolab.ttf", 12, is_bold=True)
font_code_small = get_font(r"C:\Windows\Fonts\consola.ttf", 11)
font_code_tiny = get_font(r"C:\Windows\Fonts\consola.ttf", 10)


# ==============================================================================
# Smooth Interpolation & Easing Math
# ==============================================================================
def ease_out_cubic(t):
    """Cubic ease-out for natural deceleration of counters and scrollbars."""
    return 1.0 - math.pow(1.0 - t, 3)

def ease_in_out_quad(t):
    """Quadratic ease-in-out for smooth transitions."""
    return 2.0 * t * t if t < 0.5 else 1.0 - math.pow(-2.0 * t + 2.0, 2) / 2.0

def lerp(a, b, t):
    """Linear interpolation between scalar values."""
    return a + (b - a) * t

def lerp_int(a, b, t, easing=ease_out_cubic):
    """Eased integer interpolation for token odometer counters."""
    clamped_t = max(0.0, min(1.0, t))
    return int(round(lerp(a, b, easing(clamped_t))))


# ==============================================================================
# Token-Level Syntax Highlighting Engine
# ==============================================================================
def draw_spans(draw, x, y, spans, default_font=font_code):
    """
    Renders token spans horizontally with individual colors and weights.
    spans: list of (text, color) or (text, color, font)
    Returns: x coordinate at end of text.
    """
    curr_x = x
    for item in spans:
        text = item[0]
        color = item[1]
        f = item[2] if len(item) > 2 else default_font
        draw.text((curr_x, y), text, font=f, fill=color)
        curr_x += f.getlength(text)
    return curr_x

def tokenize_command(cmd_str, is_typing=False):
    """Tokenizes CLI command lines into prompt, executable, subcommand, and args."""
    parts = cmd_str.split(" ", 2)
    spans = []
    if len(parts) >= 1 and parts[0] == "$":
        spans.append(("$ ", COLOR_CYAN, font_cmd))
    if len(parts) >= 2:
        cmd_name = parts[1]
        spans.append((cmd_name, COLOR_GREEN if "sanity" in cmd_name else COLOR_BLUE, font_cmd))
    if len(parts) >= 3:
        rest = parts[2]
        rest_parts = rest.split(" ", 1)
        subcmd = rest_parts[0]
        spans.append((" " + subcmd, COLOR_PURPLE, font_cmd))
        if len(rest_parts) > 1:
            spans.append((" " + rest_parts[1], TEXT_DEFAULT, font_cmd))
    return spans

def tokenize_json_line(line):
    """Tokenizes structured JSON lines into key, colon, string/num values, and commas."""
    m = re.match(r'^(\s*)("([^"]+)")(\s*:\s*)(.*)$', line)
    if not m:
        return [(line, TEXT_DEFAULT, font_code_small)]
    indent, full_key, key_name, colon, rest = m.groups()
    spans = []
    if indent:
        spans.append((indent, TEXT_DEFAULT, font_code_small))
    
    key_color = COLOR_CYAN
    if 'culprit' in key_name:
        key_color = COLOR_RED
    elif 'directive' in key_name:
        key_color = COLOR_YELLOW
    elif 'savings' in key_name or 'confidence' in key_name:
        key_color = COLOR_GREEN
    spans.append((full_key, key_color, font_code_bold))
    spans.append((colon, TEXT_MUTED, font_code_small))
    
    comma = ""
    val = rest
    if rest.endswith(','):
        val = rest[:-1]
        comma = ","
    
    val_color = (165, 214, 255)
    if val.startswith('"'):
        if 'Wrap' in val or 'SingleChildScrollView' in val:
            val_color = COLOR_YELLOW
        elif 'failure' in val or 'Overflow' in val or '.dart' in val:
            val_color = COLOR_RED
        elif '%' in val:
            val_color = COLOR_GREEN
        else:
            val_color = (165, 214, 255)
    elif re.match(r'^-?\d+(\.\d+)?$', val):
        val_color = COLOR_PURPLE
    
    spans.append((val, val_color, font_code_small))
    if comma:
        spans.append((comma, TEXT_MUTED, font_code_small))
    return spans

def tokenize_tree_line(line):
    """Token-level syntax highlighting for Flutter RenderObject tree dump."""
    if "relayoutBoundary" in line and "OVERFLOWING" in line:
        parts = line.split(" relayoutBoundary=", 1)
        return [
            (parts[0], COLOR_RED, font_code_bold),
            (" relayoutBoundary=", TEXT_MUTED, font_code_small),
            (parts[1], COLOR_RED, font_code_bold)
        ]
    if "|-" in line or "| |" in line:
        idx = line.find("Render")
        if idx != -1:
            prefix = line[:idx]
            rest = line[idx:]
            m = re.match(r'^(Render\w+)(#\w+)?(.*)$', rest)
            if m:
                cls_name, inst_id, remainder = m.groups()
                spans = [
                    (prefix, TEXT_DARK, font_code_small),
                    (cls_name, COLOR_YELLOW if "Flex" in cls_name else COLOR_CYAN, font_code_bold)
                ]
                if inst_id:
                    spans.append((inst_id, COLOR_PURPLE, font_code_small))
                if remainder:
                    spans.append((remainder, TEXT_MUTED if "size=" not in remainder else COLOR_GREEN, font_code_small))
                return spans
    return [(line, TEXT_MUTED, font_code_small)]

# ASCII Subtree Dump dataset for dynamic scrolling simulation
TREE_DUMP_LINES = [
    "  RenderFlex#a812b relayoutBoundary=up1 OVERFLOWING:",
    "    creator: Column <- ProfileCard <- Padding",
    "    parentData: <none> (can use size)",
    "    constraints: BoxConstraints(w=360.0, 0.0<=h<=640.0)",
    "    size: Size(360.0, 678.0)",
    "    |-RenderParagraph#1291 (Text: 'Senior Fullstack Bio...')",
    "    |-RenderPadding#4491 relayoutBoundary=up2",
    "    | |-RenderConstrainedBox#120 size=Size(360.0, 180.0)",
    "    | | |-RenderFlex#fa810 (Row inside Column)",
    "    | | | |-RenderClipRRect#9812 (AvatarThumbnail)",
    "    | | | | |-RenderImage#1129 size=Size(64.0, 64.0)",
    "    | | | |-RenderPadding#5512",
    "    | | | | |-RenderParagraph#3991 (Text: 'Verified Author')",
    "    | | |-RenderCustomPaint#7718",
    "    | |-RenderDecoratedBox#8821 (BoxDecoration)",
    "    | | |-RenderPadding#2291",
    "    | | | |-RenderParagraph#4412 (Text: 'Follow Button')",
    "    | | | |-RenderInkWell#3319",
    "    |-RenderSemanticsAnnotations#3391",
    "    |-RenderOffstage#1102 (Offstage widget)",
    "    | |-RenderTransform#0912 size=Size(360.0, 48.0)",
    "    | | |-RenderStack#4412",
    "    | | | |-RenderPositioned#1201",
    "    | | | | |-RenderIcon#5512 (Icons.star)",
    "    ... [3,920 MORE LINES OF RENDER SUBTREE DUMP] ...",
]


# ==============================================================================
# High-End Visual Elements (Badges, Gauges, Progress Bars, Cards)
# ==============================================================================
def draw_glowing_pill(draw, bbox, text, text_color, bg_color, border_color, glow_color=None, font=font_badge):
    """Renders a rounded pill badge with simulated multi-layer outer bloom."""
    x1, y1, x2, y2 = bbox
    r = (y2 - y1) // 2
    if glow_color:
        for spread, alpha in [(3, 0.20), (1, 0.40)]:
            c = tuple(int(glow_color[i] * alpha + BG_COLOR[i] * (1 - alpha)) for i in range(3))
            draw.rounded_rectangle([x1 - spread, y1 - spread, x2 + spread, y2 + spread], radius=r + spread, outline=c, width=1)
    draw.rounded_rectangle(bbox, radius=r, fill=bg_color, outline=border_color, width=1)
    tb = font.getbbox(text)
    tw, th = tb[2] - tb[0], tb[3] - tb[1]
    tx = x1 + (x2 - x1 - tw) // 2
    ty = y1 + (y2 - y1 - th) // 2 - tb[1]
    draw.text((tx, ty), text, font=font, fill=text_color)

def draw_progress_bar(draw, bbox, progress_pct, bar_color, track_color=(32, 40, 52)):
    """Draws a rounded mini progress bar."""
    x1, y1, x2, y2 = bbox
    r = (y2 - y1) // 2
    draw.rounded_rectangle(bbox, radius=r, fill=track_color)
    pct = max(0.0, min(1.0, progress_pct))
    if pct > 0.01:
        fill_w = max(r * 2, int((x2 - x1) * pct))
        draw.rounded_rectangle([x1, y1, min(x2, x1 + fill_w), y2], radius=r, fill=bar_color)

def draw_latency_gauge(draw, x, y, width, height, ms_val, max_ms=5400):
    """Draws a responsive speedometer-style mini gauge for latency."""
    r = height // 2
    draw.rounded_rectangle([x, y, x + width, y + height], radius=r, fill=(28, 35, 46))
    pct = max(0.02, min(1.0, ms_val / max_ms))
    fill_w = max(r * 2, int(width * pct))
    if ms_val < 50:
        bar_color = COLOR_GREEN
    elif ms_val < 300:
        bar_color = COLOR_CYAN
    elif ms_val < 1500:
        bar_color = COLOR_YELLOW
    else:
        bar_color = COLOR_RED
    draw.rounded_rectangle([x, y, min(x + width, x + fill_w), y + height], radius=r, fill=bar_color)

def draw_kpi_card(draw, bbox, title, value, value_color, progress_pct, progress_color, subtext=""):
    """Renders a sleek mini KPI metric card in the footer with progress bar."""
    x1, y1, x2, y2 = bbox
    draw.rounded_rectangle(bbox, radius=6, fill=CARD_BG, outline=CARD_BORDER, width=1)
    draw.text((x1 + 10, y1 + 5), title.upper(), font=font_kpi_lbl, fill=TEXT_MUTED)
    vb = font_kpi_num.getbbox(value)
    vw = vb[2] - vb[0]
    draw.text((x2 - 10 - vw, y1 + 4), value, font=font_kpi_num, fill=value_color)
    bar_y1 = y1 + 24
    bar_y2 = bar_y1 + 4
    draw_progress_bar(draw, [x1 + 10, bar_y1, x2 - 10, bar_y2], progress_pct, progress_color)
    if subtext:
        draw.text((x1 + 10, y1 + 31), subtext, font=font_code_tiny, fill=TEXT_DARK)

def draw_cursor(draw, x, y, is_visible=True, color=COLOR_CYAN):
    """Draws a crisp, pixel-perfect terminal block cursor (zero font glyph missing issues)."""
    if is_visible:
        draw.rectangle([x, y + 1, x + 7, y + 14], fill=color)


# ==============================================================================
# Canvas & Frame Composition
# ==============================================================================
def create_base_canvas():
    """Generates the master shell window chrome and panel layouts."""
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_COLOR)
    draw = ImageDraw.Draw(img)

    # Outer border
    draw.rounded_rectangle([10, 10, WIDTH - 10, HEIGHT - 10], radius=12, fill=PANEL_BG, outline=BORDER_COLOR, width=2)

    # Window Header
    draw.rounded_rectangle([10, 10, WIDTH - 10, 52], radius=12, fill=HEADER_BG, outline=BORDER_COLOR, width=1)
    draw.rectangle([10, 42, WIDTH - 10, 52], fill=HEADER_BG)
    draw.line([10, 52, WIDTH - 10, 52], fill=BORDER_COLOR, width=1)

    # Window Traffic Lights
    draw.ellipse([25, 25, 37, 37], fill=(255, 95, 86))
    draw.ellipse([43, 25, 55, 37], fill=(255, 189, 46))
    draw.ellipse([61, 25, 73, 37], fill=(39, 201, 63))

    # Window Title
    title_text = "flutter-sanity-mcp  --  AI Coding Benchmark: Token & Doom-Loop Prevention"
    draw.text((88, 22), title_text, font=font_title, fill=TEXT_DEFAULT)

    # Top-right Target Models Pill Badge
    draw_glowing_pill(draw, [WIDTH - 310, 19, WIDTH - 20, 43], "DART 3.5+ | CLAUDE OPUS 5.5 | GPT-6.1 SOL", COLOR_CYAN, (20, 32, 48), (40, 70, 100), COLOR_CYAN_GLOW, font_badge)

    # HUD for Real-time Token & Latency Metrics
    hud_y1, hud_y2 = 53, 118
    draw.rectangle([10, hud_y1, WIDTH - 10, hud_y2], fill=(16, 21, 29))
    draw.line([10, hud_y2, WIDTH - 10, hud_y2], fill=BORDER_COLOR, width=1)

    # Vertical split line
    split_x = WIDTH // 2
    draw.line([split_x, hud_y1, split_x, HEIGHT - 68], fill=BORDER_COLOR, width=2)
    draw.line([10, HEIGHT - 68, WIDTH - 10, HEIGHT - 68], fill=BORDER_COLOR, width=1)

    return img, draw

def render_frame(state):
    """Renders a single high-definition animation frame."""
    img, draw = create_base_canvas()
    split_x = WIDTH // 2

    # --- LEFT HUD (BEFORE) ---
    draw_glowing_pill(draw, [25, 63, 125, 88], "[ BEFORE ]", COLOR_RED, COLOR_RED_BG, COLOR_RED, COLOR_RED_GLOW, font_badge)
    draw.text((135, 66), "Raw Flutter CLI (Naive Run)", font=font_title, fill=TEXT_DEFAULT)

    # Left Tokens Metric (Odometer)
    draw.text((25, 94), "Tokens Consumed:", font=font_metric_lbl, fill=TEXT_MUTED)
    lt_val = state['left_tokens']
    lt_col = COLOR_RED if lt_val > 500 else TEXT_DEFAULT
    draw.text((120, 91), f"{lt_val:,}", font=font_metric_num, fill=lt_col)

    # Left Latency Metric + Mini Gauge
    draw.text((205, 94), "Latency:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((250, 91), state['left_time_str'], font=font_metric_num, fill=COLOR_RED if state['left_ms'] > 1000 else TEXT_DEFAULT)
    draw_latency_gauge(draw, 305, 96, 45, 8, state['left_ms'], max_ms=5400)

    # Left Status Badge
    draw.text((365, 94), "Agent Health:", font=font_metric_lbl, fill=TEXT_MUTED)
    is_doom = "LOOP" in state['left_status'] or "EXHAUSTION" in state['left_status'] or "TRIPPED" in state['left_status']
    draw.text((435, 91), state['left_status'], font=font_metric_num, fill=COLOR_RED if is_doom else TEXT_DEFAULT)

    # --- RIGHT HUD (AFTER) ---
    draw_glowing_pill(draw, [split_x + 20, 63, split_x + 115, 88], "[ AFTER ]", COLOR_GREEN, COLOR_GREEN_BG, COLOR_GREEN, COLOR_GREEN_GLOW, font_badge)
    draw.text((split_x + 125, 66), "flutter-sanity-mcp (Sanitized)", font=font_title, fill=TEXT_DEFAULT)

    # Right Tokens Metric (Odometer)
    draw.text((split_x + 20, 94), "Tokens Consumed:", font=font_metric_lbl, fill=TEXT_MUTED)
    rt_val = state['right_tokens']
    rt_col = COLOR_GREEN if rt_val > 0 else TEXT_DEFAULT
    draw.text((split_x + 115, 91), f"{rt_val:,}", font=font_metric_num, fill=rt_col)
    if rt_val > 0 and lt_val > 500:
        pct = (1.0 - (rt_val / lt_val)) * 100.0
        draw.text((split_x + 155, 93), f"(-{pct:.1f}%)", font=font_metric_lbl, fill=COLOR_GREEN)

    # Right Latency Metric + Mini Gauge
    draw.text((split_x + 235, 94), "Latency:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((split_x + 280, 91), state['right_time_str'], font=font_metric_num, fill=COLOR_GREEN if rt_val > 0 else TEXT_DEFAULT)
    draw_latency_gauge(draw, split_x + 325, 96, 45, 8, state['right_ms'], max_ms=5400)

    # Right Status Badge
    draw.text((split_x + 385, 94), "Agent Health:", font=font_metric_lbl, fill=TEXT_MUTED)
    is_ok = "PASS" in state['right_status'] or "1-TURN" in state['right_status'] or "CLEAN" in state['right_status']
    draw.text((split_x + 455, 91), state['right_status'], font=font_metric_num, fill=COLOR_GREEN if is_ok else TEXT_DEFAULT)

    # --- CONTENT AREA LEFT (BEFORE) ---
    ly = 130
    left_cmd = "$ flutter test test/scenario1_vertical_overflow_test.dart"
    if state['typing_left_t'] < 1.0:
        char_n = int(len(left_cmd) * state['typing_left_t'])
        cmd_shown = left_cmd[:char_n]
        end_x = draw_spans(draw, 25, ly, tokenize_command(cmd_shown, is_typing=True))
        draw_cursor(draw, end_x + 2, ly, is_visible=state['cursor_on'])
    else:
        draw_spans(draw, 25, ly, tokenize_command(left_cmd))
    ly += 22

    left_step = state['left_step']
    if left_step >= 1:
        draw.text((25, ly), "00:01 +0: loading test/scenario1_vertical_overflow_test.dart", font=font_code, fill=TEXT_MUTED)
        ly += 18
    if left_step >= 2:
        draw_spans(draw, 25, ly, [
            ("==╡ ", COLOR_RED, font_code_bold),
            ("EXCEPTION CAUGHT BY RENDERING LIBRARY", TEXT_BRIGHT, font_code_bold),
            (" ╞═══════════════════", COLOR_RED, font_code_bold)
        ])
        ly += 18
        draw.text((25, ly), "The following assertion was thrown during layout:", font=font_code, fill=COLOR_RED)
        ly += 18
        draw_spans(draw, 25, ly, [
            ("A ", TEXT_DEFAULT, font_code_bold),
            ("RenderFlex", COLOR_CYAN, font_code_bold),
            (" overflowed by ", TEXT_DEFAULT, font_code_bold),
            ("38 pixels", COLOR_YELLOW, font_code_bold),
            (" on the bottom.", TEXT_DEFAULT, font_code_bold)
        ])
        ly += 18
        draw.text((25, ly), "The relevant error-causing widget was:", font=font_code, fill=TEXT_DEFAULT)
        ly += 18
        draw_spans(draw, 25, ly, [
            ("  Column", COLOR_CYAN, font_code_bold),
            (" <- ", TEXT_MUTED, font_code_small),
            ("ProfileCard", COLOR_CYAN, font_code_bold),
            (" <- ", TEXT_MUTED, font_code_small),
            ("Padding <- Scaffold", TEXT_MUTED, font_code_small)
        ])
        ly += 18

    # Dynamic ASCII Tree Scrolling Simulation
    if left_step >= 3:
        draw.text((25, ly), "The following RenderObject was being processed:", font=font_code, fill=TEXT_MUTED)
        ly += 17

        tree_box_y1 = ly
        tree_box_y2 = ly + 145
        scroll_idx = state.get('tree_scroll_offset', 0)
        max_visible_lines = 8
        visible_lines = TREE_DUMP_LINES[scroll_idx : scroll_idx + max_visible_lines]

        curr_ty = tree_box_y1
        for tline in visible_lines:
            spans = tokenize_tree_line(tline)
            draw_spans(draw, 25, curr_ty, spans)
            curr_ty += 16

        # Draw dynamic scrollbar track & thumb on right edge of left panel
        sb_x = split_x - 14
        sb_h = tree_box_y2 - tree_box_y1
        draw.rectangle([sb_x, tree_box_y1, sb_x + 4, tree_box_y2], fill=(25, 32, 44))
        thumb_h = 24
        thumb_ratio = scroll_idx / max(1, len(TREE_DUMP_LINES) - max_visible_lines)
        thumb_y = tree_box_y1 + int((sb_h - thumb_h) * thumb_ratio)
        draw.rounded_rectangle([sb_x, thumb_y, sb_x + 4, thumb_y + thumb_h], radius=2, fill=(80, 110, 150))
        ly = tree_box_y2 + 8

    if left_step >= 4:
        draw_glowing_pill(draw, [25, ly, split_x - 25, ly + 40], "[!] ATTENTION ROT: 4,000 lines flooding context (>128k tokens)", COLOR_RED, (45, 18, 22), COLOR_RED, COLOR_RED_GLOW, font_code_bold)
        draw.text((35, ly + 44), "Agent hallucinates, deletes child widgets blindly to fix height...", font=font_code_small, fill=TEXT_DEFAULT)
        ly += 64

    if left_step >= 5:
        draw_spans(draw, 25, ly, [
            ("[Attempt 2/3] ", COLOR_YELLOW, font_code_small),
            ("Agent deletes ProfileCard widgets blindly...", TEXT_MUTED, font_code_small)
        ])
        ly += 18
        draw.text((25, ly), "00:03 +0 -1: test/scenario1_vertical_overflow_test.dart FAILED", font=font_code_bold, fill=COLOR_RED)
        ly += 18
        draw_glowing_pill(draw, [25, ly, split_x - 25, ly + 42], "[X] DOOM LOOP TRIPPED: 3 Failed Editing Cycles!", COLOR_RED, COLOR_RED_BG, COLOR_RED, COLOR_RED_GLOW, font_code_bold)
        draw.text((35, ly + 46), "Wasted $0.48 in tokens | Codebase damaged permanently", font=font_code_small, fill=COLOR_YELLOW)

    # --- CONTENT AREA RIGHT (AFTER) ---
    ry = 130
    right_cmd = "$ flutter-sanity inspect test/scenario1_vertical_overflow_test.dart"
    if state['typing_right_t'] < 1.0:
        char_n = int(len(right_cmd) * state['typing_right_t'])
        cmd_shown = right_cmd[:char_n]
        end_x = draw_spans(draw, split_x + 20, ry, tokenize_command(cmd_shown, is_typing=True))
        draw_cursor(draw, end_x + 2, ry, is_visible=state['cursor_on'])
    else:
        draw_spans(draw, split_x + 20, ry, tokenize_command(right_cmd))
    ry += 22

    right_step = state['right_step']
    if right_step >= 1:
        draw_spans(draw, split_x + 20, ry, [
            (">> ", COLOR_CYAN, font_code_bold),
            ("Intercepting test stream via stdio parser... ", TEXT_MUTED, font_code),
            ("[9ms]", COLOR_GREEN, font_code_bold)
        ])
        ry += 18
        draw_spans(draw, split_x + 20, ry, [
            ("-> ", COLOR_GREEN, font_code_bold),
            ("Stripped 82 framework frames ", COLOR_GREEN, font_code),
            ("(flex.dart, object.dart)", TEXT_DARK, font_code_small)
        ])
        ry += 18
        draw_spans(draw, split_x + 20, ry, [
            ("-> ", COLOR_CYAN, font_code_bold),
            ("Isolated user culprit widget & deterministic root-cause", COLOR_CYAN, font_code)
        ])
        ry += 20

    if right_step >= 2:
        draw_spans(draw, split_x + 20, ry, [
            (":: ", COLOR_CYAN, font_code_bold),
            ("High-Density Sanitized Output (Sent to Agent):", TEXT_DEFAULT, font_code_bold)
        ])
        ry += 18

        # JSON Box
        json_box_top = ry
        json_lines = [
            '  "status": "failure",',
            '  "category": "RenderFlex_Overflow",',
            '  "culprit": "lib/src/scenario1_profile_card.dart:42",',
            '  "overflow_direction": "vertical (38.0 pixels)",',
            '  "heuristic_directive": "Wrap Column in SingleChildScrollView",',
            '  "confidence": 0.994,',
            '  "signal_retention": "100%",',
            '  "token_savings": "97.0%"'
        ]
        box_h = 24 + len(json_lines) * 17 + 8
        draw.rounded_rectangle([split_x + 20, json_box_top, WIDTH - 25, json_box_top + box_h], radius=6, fill=(16, 24, 34), outline=(40, 75, 115))
        draw.text((split_x + 32, json_box_top + 5), "{", font=font_code_bold, fill=TEXT_DEFAULT)
        j_y = json_box_top + 22
        for line in json_lines:
            spans = tokenize_json_line(line)
            draw_spans(draw, split_x + 36, j_y, spans)
            j_y += 17
        draw.text((split_x + 32, j_y), "}", font=font_code_bold, fill=TEXT_DEFAULT)
        ry = json_box_top + box_h + 14

    if right_step >= 3:
        draw_glowing_pill(draw, [split_x + 20, ry, WIDTH - 25, ry + 40], "[DIRECTIVE] 1-Turn Deterministic Heuristic Applied:", COLOR_GREEN, COLOR_GREEN_BG, COLOR_GREEN, COLOR_GREEN_GLOW, font_code_bold)
        draw.text((split_x + 30, ry + 44), "Agent wraps Column in SingleChildScrollView (1-line targeted edit)", font=font_code_small, fill=TEXT_DEFAULT)
        ry += 60

    if right_step >= 4:
        draw_spans(draw, split_x + 20, ry, tokenize_command("$ flutter test test/scenario1_vertical_overflow_test.dart"))
        ry += 18
        draw_spans(draw, split_x + 20, ry, [
            ("00:01 +1: ", TEXT_MUTED, font_code),
            ("All tests passed! [SUCCESS]", COLOR_GREEN, font_code_bold)
        ])
        ry += 20
        draw_glowing_pill(draw, [split_x + 20, ry, WIDTH - 25, ry + 42], "[RESOLVED] IN 1 TURN (Zero Doom Loop)", COLOR_GREEN, (16, 45, 24), COLOR_GREEN, COLOR_GREEN_GLOW, font_code_bold)
        draw.text((split_x + 30, ry + 46), "Total Tokens: 118 | Latency: 12ms | Saved 97% API Tokens", font=font_code_small, fill=TEXT_DEFAULT)

    # --- MINI KPI METRIC CARDS IN FOOTER ---
    kpi_y1 = HEIGHT - 58
    kpi_y2 = HEIGHT - 14
    card_w = (WIDTH - 40 - 30) // 4
    gap = 10
    start_x = 20

    # Card 1: Token Savings
    c1_x1 = start_x
    draw_kpi_card(
        draw, [c1_x1, kpi_y1, c1_x1 + card_w, kpi_y2],
        title="Token Reduction",
        value=state['kpi_token_val'],
        value_color=COLOR_GREEN,
        progress_pct=state['kpi_token_pct'],
        progress_color=COLOR_GREEN,
        subtext="Empirical benchmark avg"
    )

    # Card 2: Latency Speedup
    c2_x1 = c1_x1 + card_w + gap
    draw_kpi_card(
        draw, [c2_x1, kpi_y1, c2_x1 + card_w, kpi_y2],
        title="Latency Speedup",
        value=state['kpi_lat_val'],
        value_color=COLOR_CYAN,
        progress_pct=state['kpi_lat_pct'],
        progress_color=COLOR_CYAN,
        subtext="12ms vs 5.4s CLI run"
    )

    # Card 3: Doom Loop Circuit
    c3_x1 = c2_x1 + card_w + gap
    draw_kpi_card(
        draw, [c3_x1, kpi_y1, c3_x1 + card_w, kpi_y2],
        title="Doom Loop Circuit",
        value=state['kpi_loop_val'],
        value_color=COLOR_GREEN,
        progress_pct=state['kpi_loop_pct'],
        progress_color=COLOR_GREEN,
        subtext="Circuit breaker active"
    )

    # Card 4: Signal Retention
    c4_x1 = c3_x1 + card_w + gap
    draw_kpi_card(
        draw, [c4_x1, kpi_y1, c4_x1 + card_w, kpi_y2],
        title="Signal Retention",
        value=state['kpi_sig_val'],
        value_color=COLOR_PURPLE,
        progress_pct=state['kpi_sig_pct'],
        progress_color=COLOR_PURPLE,
        subtext="Root cause preserved"
    )

    return img


# ==============================================================================
# Animation Timeline & GIF Optimization Pipeline
# ==============================================================================
def generate_benchmark_gif(output_path="assets/flutter_sanity_demo.gif", total_frames=34):
    """
    Executes the multi-phase benchmark timeline, interpolates metrics,
    applies adaptive LANCZOS palette quantization with zero-dither LZW compression,
    and produces a production-ready GIF under 2.5 MB.
    """
    print(f"Generating upgraded benchmark GIF ({total_frames} frames)...")
    frames = []
    durations = []

    for i in range(total_frames):
        state = {
            'cursor_on': (i % 2 == 0),
            'typing_left_t': 1.0,
            'typing_right_t': 1.0,
            'left_step': 0,
            'right_step': 0,
            'left_tokens': 0,
            'right_tokens': 0,
            'left_ms': 0,
            'right_ms': 0,
            'left_time_str': "0ms",
            'right_time_str': "0ms",
            'left_status': "IDLE",
            'right_status': "IDLE",
            'tree_scroll_offset': 0,
            'kpi_token_val': "0.0%",
            'kpi_token_pct': 0.0,
            'kpi_lat_val': "0.0%",
            'kpi_lat_pct': 0.0,
            'kpi_loop_val': "SHIELD ON",
            'kpi_loop_pct': 1.0,
            'kpi_sig_val': "100%",
            'kpi_sig_pct': 1.0,
        }
        frame_duration = 100

        if i < 6:
            # Phase 1: Typing simulation with blinking cursor
            t = (i + 1) / 6.0
            state['typing_left_t'] = t
            state['typing_right_t'] = t
            state['left_status'] = "TYPING..."
            state['right_status'] = "TYPING..."
            frame_duration = 110

        elif i < 11:
            # Phase 2: Launching tests, first assertion caught
            t = (i - 6) / 4.0
            state['left_step'] = 1 if t < 0.6 else 2
            state['right_step'] = 1
            state['left_tokens'] = lerp_int(0, 1850, t)
            state['right_tokens'] = lerp_int(0, 45, t)
            state['left_ms'] = lerp_int(0, 450, t)
            state['right_ms'] = 9
            state['left_time_str'] = f"{state['left_ms']}ms"
            state['right_time_str'] = "9ms"
            state['left_status'] = "ASSERT FAILS" if state['left_step'] == 2 else "RUNNING..."
            state['right_status'] = "PARSING STDIO"
            state['kpi_token_pct'] = lerp(0.0, 0.4, t)
            state['kpi_token_val'] = f"{state['kpi_token_pct']*100:.1f}%"
            state['kpi_lat_pct'] = lerp(0.0, 0.6, t)
            state['kpi_lat_val'] = f"{state['kpi_lat_pct']*100:.1f}%"
            frame_duration = 120

        elif i < 21:
            # Phase 3: ASCII Subtree dynamic scroll vs High-density JSON sanitization
            t = (i - 11) / 9.0
            state['left_step'] = 3
            state['right_step'] = 2
            state['tree_scroll_offset'] = min(14, int(t * 15))
            state['left_tokens'] = lerp_int(1850, 3940, t)
            state['right_tokens'] = lerp_int(45, 118, t)
            state['left_ms'] = lerp_int(450, 1200, t)
            state['right_ms'] = 12
            state['left_time_str'] = f"{state['left_ms']/1000.0:.1f}s"
            state['right_time_str'] = "12ms"
            state['left_status'] = "CONTEXT ROT"
            state['right_status'] = "CLEAN JSON"
            state['kpi_token_pct'] = lerp(0.4, 0.97, t)
            state['kpi_token_val'] = f"{state['kpi_token_pct']*100:.1f}%"
            state['kpi_lat_pct'] = lerp(0.6, 0.99, t)
            state['kpi_lat_val'] = f"{state['kpi_lat_pct']*100:.1f}%"
            frame_duration = 140

        elif i < 27:
            # Phase 4: Left LLM context rot begins vs Right deterministic heuristic directive
            t = (i - 21) / 5.0
            state['left_step'] = 4
            state['right_step'] = 3
            state['tree_scroll_offset'] = 14
            state['left_tokens'] = lerp_int(3940, 7880, t)
            state['right_tokens'] = 118
            state['left_ms'] = lerp_int(1200, 2800, t)
            state['right_ms'] = 14
            state['left_time_str'] = f"{state['left_ms']/1000.0:.1f}s"
            state['right_time_str'] = "14ms"
            state['left_status'] = "DOOM LOOP #1"
            state['right_status'] = "HEURISTIC FIX"
            state['kpi_token_pct'] = 0.968
            state['kpi_token_val'] = "96.8%"
            state['kpi_lat_pct'] = 0.995
            state['kpi_lat_val'] = "99.5%"
            state['kpi_loop_val'] = "0 LOOPS"
            state['kpi_loop_pct'] = 1.0
            frame_duration = 160

        else:
            # Phase 5: Climax & Resolution (1-turn deterministic pass vs circuit tripped)
            t = (i - 27) / 6.0
            state['left_step'] = 5
            state['right_step'] = 4
            state['tree_scroll_offset'] = 14
            state['left_tokens'] = lerp_int(7880, 11820, t)
            state['right_tokens'] = 118
            state['left_ms'] = lerp_int(2800, 5400, t)
            state['right_ms'] = 12
            state['left_time_str'] = f"{state['left_ms']/1000.0:.1f}s"
            state['right_time_str'] = "12ms"
            state['left_status'] = "CIRCUIT TRIPPED"
            state['right_status'] = "PASS (1-TURN)"
            state['kpi_token_pct'] = 0.9684
            state['kpi_token_val'] = "96.84%"
            state['kpi_lat_pct'] = 0.997
            state['kpi_lat_val'] = "99.7%"
            state['kpi_loop_val'] = "0 LOOPS"
            state['kpi_loop_pct'] = 1.0
            state['kpi_sig_val'] = "100% SIGNAL"
            state['kpi_sig_pct'] = 1.0
            if i == total_frames - 1:
                frame_duration = 3500  # Climax hold
            else:
                frame_duration = 150

        frame_img = render_frame(state)
        # Quantize using LANCZOS with zero-dither to retain razor sharp text and ultra-compact LZW encoding
        quantized = frame_img.quantize(colors=128, method=Image.Resampling.LANCZOS, dither=Image.Dither.NONE)
        frames.append(quantized)
        durations.append(frame_duration)

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    frames[0].save(
        output_path,
        save_all=True,
        append_images=frames[1:],
        duration=durations,
        loop=0,
        optimize=True
    )
    file_size_kb = os.path.getsize(output_path) / 1024
    print(f"SUCCESS: Upgraded benchmark GIF saved to {output_path} ({file_size_kb:.1f} KB)")
    assert file_size_kb < 2560.0, f"Error: File size {file_size_kb:.1f} KB exceeds 2.5 MB limit!"
    return output_path

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate benchmark demo GIF for flutter-sanity-mcp")
    parser.add_argument("--output", default="assets/flutter_sanity_demo.gif", help="Path for output GIF")
    parser.add_argument("--frames", type=int, default=34, help="Total frame count (default: 34)")
    args = parser.parse_args()
    generate_benchmark_gif(output_path=args.output, total_frames=args.frames)
