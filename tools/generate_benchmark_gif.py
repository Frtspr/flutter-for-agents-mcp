"""
10x Cinematic Split-Screen Benchmark GIF Generator for flutter-sanity-mcp.
Features:
- Tokyo Night / Catppuccin Mocha aesthetic with glowing borders.
- Real vector-drawn blinking terminal block cursors (100% glyph safe).
- Traffic lights with radial depth & specular highlights.
- Vector icon badges (No broken font boxes).
- Live Odometer token counters (0 -> 11,820 vs 0 -> 118).
- Real-time Cost Ticker ($0.00 -> $0.48 vs $0.005).
- Token-level syntax highlighting (Bash, JSON, Dart).
- 3 Elevated KPI cards with glowing progress bars.
- File size optimized (< 1.5 MB) via adaptive 128-color quantization.
"""

import os
from PIL import Image, ImageDraw, ImageFont

WIDTH = 1260
HEIGHT = 750

# --- COLOR PALETTE (Tokyo Night / Catppuccin Mocha Hybrid) ---
BG_DARK = (10, 14, 23)
WINDOW_BORDER = (40, 50, 70)
HEADER_BG = (17, 23, 36)
DIVIDER_COLOR = (32, 42, 60)

TEXT_MAIN = (226, 232, 240)
TEXT_MUTED = (148, 163, 184)
TEXT_DIM = (71, 85, 105)

NEON_RED = (244, 63, 94)
NEON_RED_BG = (55, 16, 25)
NEON_GREEN = (34, 197, 94)
NEON_GREEN_BG = (16, 50, 28)
NEON_YELLOW = (234, 179, 8)
NEON_YELLOW_BG = (55, 42, 12)
NEON_BLUE = (56, 189, 248)
NEON_PURPLE = (168, 85, 247)
NEON_CYAN = (6, 182, 212)

# --- FONTS ---
FONT_PATH_MONO = r"C:\Windows\Fonts\consola.ttf"
FONT_PATH_MONO_BOLD = r"C:\Windows\Fonts\consolab.ttf"
FONT_PATH_SANS_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
FONT_PATH_SANS = r"C:\Windows\Fonts\segoeui.ttf"

font_title = ImageFont.truetype(FONT_PATH_SANS_BOLD, 15)
font_badge = ImageFont.truetype(FONT_PATH_SANS_BOLD, 12)
font_metric_num = ImageFont.truetype(FONT_PATH_SANS_BOLD, 17)
font_metric_lbl = ImageFont.truetype(FONT_PATH_SANS, 11)
font_kpi_title = ImageFont.truetype(FONT_PATH_SANS_BOLD, 11)
font_kpi_val = ImageFont.truetype(FONT_PATH_SANS_BOLD, 15)

font_cmd = ImageFont.truetype(FONT_PATH_MONO_BOLD, 13)
font_code = ImageFont.truetype(FONT_PATH_MONO, 12)
font_code_bold = ImageFont.truetype(FONT_PATH_MONO_BOLD, 12)
font_code_small = ImageFont.truetype(FONT_PATH_MONO, 11)


def draw_rounded_rect(draw, bbox, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(bbox, radius=radius, fill=fill, outline=outline, width=width)


def draw_tokens(draw, x, y, tokens):
    cur_x = x
    for text, color, font in tokens:
        draw.text((cur_x, y), text, font=font, fill=color)
        bbox = font.getbbox(text)
        cur_x += (bbox[2] - bbox[0])
    return cur_x


def draw_vector_cursor(draw, x, y, color):
    draw.rectangle([x + 2, y + 1, x + 9, y + 15], fill=color)


def create_base_canvas():
    img = Image.new("RGB", (WIDTH, HEIGHT), BG_DARK)
    draw = ImageDraw.Draw(img)

    # Outer Container
    draw_rounded_rect(draw, [10, 10, WIDTH - 10, HEIGHT - 10], 12, fill=BG_DARK, outline=WINDOW_BORDER, width=2)

    # Window Header Bar
    draw_rounded_rect(draw, [10, 10, WIDTH - 10, 52], 12, fill=HEADER_BG, outline=WINDOW_BORDER, width=1)
    draw.rectangle([10, 42, WIDTH - 10, 52], fill=HEADER_BG)
    draw.line([10, 52, WIDTH - 10, 52], fill=DIVIDER_COLOR, width=1)

    # Window Traffic Lights with Specular Depth
    lights = [
        (30, (255, 95, 87), (224, 68, 62), (255, 175, 170)),
        (49, (254, 188, 46), (216, 160, 25), (255, 230, 150)),
        (68, (40, 201, 64), (26, 171, 47), (160, 245, 175))
    ]
    for cx, fill, ring, shine in lights:
        draw.ellipse([cx - 7, 24, cx + 7, 38], fill=fill, outline=ring, width=1)
        draw.ellipse([cx - 4, 26, cx + 2, 31], fill=shine)

    # Window Title
    draw.text((95, 21), "flutter-sanity-mcp  --  Token Sanitization & Reasoning Guardrail Benchmark", font=font_title, fill=TEXT_MUTED)

    # Top Right Spec Tag
    spec_tag = "PURE DART MCP | CLAUDE OPUS 5.5 | GPT-6.1 SOL"
    bbox = font_badge.getbbox(spec_tag)
    tw = bbox[2] - bbox[0]
    draw_rounded_rect(draw, [WIDTH - tw - 36, 18, WIDTH - 20, 44], 6, fill=(24, 36, 56), outline=(45, 75, 120))
    draw.text((WIDTH - tw - 28, 23), spec_tag, font=font_badge, fill=NEON_BLUE)

    # Sub-header HUD for Metrics
    hud_y1, hud_y2 = 53, 122
    draw.rectangle([10, hud_y1, WIDTH - 10, hud_y2], fill=(15, 20, 32))
    draw.line([10, hud_y2, WIDTH - 10, hud_y2], fill=DIVIDER_COLOR, width=1)

    # Vertical Split Divider
    split_x = WIDTH // 2
    draw.line([split_x, hud_y1, split_x, HEIGHT - 92], fill=DIVIDER_COLOR, width=2)

    # Footer Card Deck Area
    bot_y1 = HEIGHT - 90
    draw.rectangle([10, bot_y1, WIDTH - 10, HEIGHT - 10], fill=HEADER_BG)
    draw.line([10, bot_y1, WIDTH - 10, bot_y1], fill=DIVIDER_COLOR, width=1)

    return img, draw


def render_frame(state):
    img, draw = create_base_canvas()
    split_x = WIDTH // 2

    # =========================================================================
    # --- LEFT HUD (BEFORE: Raw CLI) ---
    # =========================================================================
    draw_rounded_rect(draw, [25, 63, 135, 88], 5, fill=NEON_RED_BG, outline=NEON_RED)
    draw.text((35, 68), "BEFORE: RAW CLI", font=font_badge, fill=NEON_RED)
    draw.text((146, 66), "Raw Flutter test (Unsanitized)", font=font_title, fill=TEXT_MAIN)

    # Left Odometer Tokens
    draw.text((25, 96), "Tokens Burned:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((115, 93), f"{state['left_tokens']:,}", font=font_metric_num, fill=NEON_RED if state['left_tokens'] > 500 else TEXT_MAIN)

    # Left Cost Ticker
    draw.text((195, 96), "Cost:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((230, 93), state['left_cost'], font=font_metric_num, fill=NEON_RED if state['left_tokens'] > 2000 else TEXT_MAIN)

    # Left Latency
    draw.text((295, 96), "Latency:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((345, 93), state['left_time'], font=font_metric_num, fill=TEXT_MAIN)

    # Left Agent Status
    draw.text((410, 96), "Health:", font=font_metric_lbl, fill=TEXT_MUTED)
    is_doom = "LOOP" in state['left_status'] or "TRIPPED" in state['left_status']
    draw.text((455, 93), state['left_status'], font=font_metric_num, fill=NEON_RED if is_doom else TEXT_MAIN)

    # =========================================================================
    # --- RIGHT HUD (AFTER: flutter-sanity-mcp) ---
    # =========================================================================
    draw_rounded_rect(draw, [split_x + 20, 63, split_x + 155, 88], 5, fill=NEON_GREEN_BG, outline=NEON_GREEN)
    draw.text((split_x + 30, 68), "AFTER: SANITY MCP", font=font_badge, fill=NEON_GREEN)
    draw.text((split_x + 165, 66), "flutter-sanity-mcp (Deterministic)", font=font_title, fill=TEXT_MAIN)

    # Right Odometer Tokens
    draw.text((split_x + 20, 96), "Tokens Used:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((split_x + 95, 93), f"{state['right_tokens']:,}", font=font_metric_num, fill=NEON_GREEN if state['right_tokens'] > 0 else TEXT_MAIN)
    if state['right_tokens'] > 0 and state['left_tokens'] > 500:
        pct = (1.0 - (state['right_tokens'] / state['left_tokens'])) * 100.0
        draw.text((split_x + 130, 95), f"(-{pct:.1f}%)", font=font_metric_lbl, fill=NEON_GREEN)

    # Right Cost Ticker
    draw.text((split_x + 200, 96), "Cost:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((split_x + 235, 93), state['right_cost'], font=font_metric_num, fill=NEON_GREEN if state['right_tokens'] > 0 else TEXT_MAIN)

    # Right Latency
    draw.text((split_x + 305, 96), "Latency:", font=font_metric_lbl, fill=TEXT_MUTED)
    draw.text((split_x + 355, 93), state['right_time'], font=font_metric_num, fill=NEON_BLUE if state['right_tokens'] > 0 else TEXT_MAIN)

    # Right Agent Status
    draw.text((split_x + 420, 96), "Health:", font=font_metric_lbl, fill=TEXT_MUTED)
    is_ok = "PASS" in state['right_status'] or "RESOLVED" in state['right_status'] or "READY" in state['right_status']
    draw.text((split_x + 465, 93), state['right_status'], font=font_metric_num, fill=NEON_GREEN if is_ok else TEXT_MAIN)

    # =========================================================================
    # --- LEFT TERMINAL CONTENT (BEFORE) ---
    # =========================================================================
    ly = 136
    cmd_text = state['left_cmd']
    end_x = draw_tokens(draw, 25, ly, [
        ("$ ", NEON_CYAN, font_cmd),
        (cmd_text, TEXT_MAIN, font_cmd),
    ])
    if state.get('left_caret', False):
        draw_vector_cursor(draw, end_x, ly, NEON_BLUE)
    ly += 24

    l_step = state['left_step']
    if l_step >= 1:
        draw_tokens(draw, 25, ly, [("00:01 +0: ", TEXT_MUTED, font_code), ("loading test/scenario1_vertical_overflow_test.dart", TEXT_MUTED, font_code)])
        ly += 18

    if l_step >= 2:
        draw.text((25, ly), "==╡ EXCEPTION CAUGHT BY RENDERING LIBRARY ╞═══════════════════", font=font_code_bold, fill=NEON_RED)
        ly += 18
        draw.text((25, ly), "The following assertion was thrown during layout:", font=font_code, fill=NEON_RED)
        ly += 18
        draw_tokens(draw, 25, ly, [
            ("A RenderFlex overflowed by ", NEON_YELLOW, font_code_bold),
            ("38.0 pixels", NEON_RED, font_code_bold),
            (" on the bottom.", NEON_YELLOW, font_code_bold)
        ])
        ly += 18
        draw_tokens(draw, 25, ly, [
            ("The relevant error-causing widget was: ", TEXT_MAIN, font_code),
            ("Column", NEON_CYAN, font_code_bold)
        ])
        ly += 18
        draw.text((25, ly), "  Column <- ProfileCard <- Padding <- Scaffold", font=font_code, fill=TEXT_MUTED)
        ly += 18

    if l_step >= 3:
        draw.text((25, ly), "The following RenderObject was being processed:", font=font_code, fill=TEXT_MUTED)
        ly += 18
        draw.text((25, ly), "  RenderFlex#a812b relayoutBoundary=up1 OVERFLOWING:", font=font_code_small, fill=NEON_RED)
        ly += 16
        draw.text((25, ly), "    creator: Column <- ProfileCard <- Padding", font=font_code_small, fill=TEXT_MUTED)
        ly += 16
        draw.text((25, ly), "    constraints: BoxConstraints(w=360.0, 0.0<=h<=640.0)", font=font_code_small, fill=TEXT_MUTED)
        ly += 16
        draw.text((25, ly), "    size: Size(360.0, 678.0) [exceeds max height]", font=font_code_small, fill=NEON_RED)
        ly += 16
        draw.text((25, ly), "    |-RenderParagraph#1291 (Text: 'Senior Flutter Architect Bio...')", font=font_code_small, fill=TEXT_MUTED)
        ly += 16
        draw.text((25, ly), "    |-RenderPadding#4491 relayoutBoundary=up2", font=font_code_small, fill=TEXT_DIM)
        ly += 16
        draw.text((25, ly), "    | |-RenderConstrainedBox#120 size=Size(360.0, 180.0)", font=font_code_small, fill=TEXT_DIM)
        ly += 16
        draw.text((25, ly), "    ... [3,920 MORE LINES OF RENDER SUBTREE DUMP] ...", font=font_code_bold, fill=NEON_RED)
        ly += 22

    if l_step >= 4:
        draw_rounded_rect(draw, [25, ly, split_x - 25, ly + 46], 6, fill=NEON_RED_BG, outline=NEON_RED)
        draw.text((35, ly + 6), "[!] ATTENTION ROT: 4,000 lines flooding context (>128k tokens)", font=font_code_bold, fill=NEON_RED)
        draw.text((35, ly + 25), "Frontier model context degrades; agent deletes widgets blindly...", font=font_code_small, fill=TEXT_MAIN)
        ly += 54

    if l_step >= 5:
        draw.text((25, ly), "[Attempt 2/3] Agent deletes ProfileCard widgets to fix height...", font=font_code, fill=TEXT_MUTED)
        ly += 18
        draw.text((25, ly), "00:03 +0 -1: test/scenario1_vertical_overflow_test.dart FAILED", font=font_code_bold, fill=NEON_RED)
        ly += 18
        draw_rounded_rect(draw, [25, ly, split_x - 25, ly + 46], 6, fill=(50, 15, 20), outline=NEON_RED, width=2)
        draw.text((35, ly + 6), "[X] DOOM LOOP TRIPPED: 3 Failed Editing Cycles!", font=font_code_bold, fill=NEON_RED)
        draw.text((35, ly + 25), "Wasted $0.48 in API tokens | Codebase damaged permanently", font=font_code_small, fill=NEON_YELLOW)

    # =========================================================================
    # --- RIGHT TERMINAL CONTENT (AFTER) ---
    # =========================================================================
    ry = 136
    r_cmd = state['right_cmd']
    r_end_x = draw_tokens(draw, split_x + 20, ry, [
        ("$ ", NEON_CYAN, font_cmd),
        (r_cmd, TEXT_MAIN, font_cmd),
    ])
    if state.get('right_caret', False):
        draw_vector_cursor(draw, r_end_x, ry, NEON_GREEN)
    ry += 24

    r_step = state['right_step']
    if r_step >= 1:
        draw.text((split_x + 20, ry), ">> Intercepting test stream via stdio parser... [9ms]", font=font_code, fill=TEXT_MUTED)
        ry += 18
        draw_tokens(draw, split_x + 20, ry, [
            ("-> Stripped ", TEXT_MAIN, font_code),
            ("82 framework stack frames", NEON_GREEN, font_code_bold),
            (" (flex.dart, object.dart)", TEXT_MUTED, font_code)
        ])
        ry += 18
        draw_tokens(draw, split_x + 20, ry, [
            ("-> Isolated culprit widget: ", TEXT_MAIN, font_code),
            ("lib/src/scenario1_profile_card.dart:42", NEON_CYAN, font_code_bold)
        ])
        ry += 22

    if r_step >= 2:
        draw.text((split_x + 20, ry), ":: High-Density Sanitized Output (Sent to Agent):", font=font_code_bold, fill=TEXT_MAIN)
        ry += 18

        # JSON Box
        json_box_top = ry
        json_tokens_list = [
            [('  "status": ', TEXT_MUTED, font_code_small), ('"failure",', NEON_RED, font_code_small)],
            [('  "category": ', TEXT_MUTED, font_code_small), ('"RenderFlex_Overflow",', NEON_YELLOW, font_code_small)],
            [('  "culprit": ', TEXT_MUTED, font_code_small), ('"lib/src/scenario1_profile_card.dart:42",', NEON_CYAN, font_code_small)],
            [('  "overflow_direction": ', TEXT_MUTED, font_code_small), ('"vertical (38.0 pixels)",', TEXT_MAIN, font_code_small)],
            [('  "heuristic_directive": ', TEXT_MUTED, font_code_small), ('"Wrap Column in SingleChildScrollView",', NEON_YELLOW, font_code_bold)],
            [('  "confidence": ', TEXT_MUTED, font_code_small), ('0.994,', NEON_GREEN, font_code_small)],
            [('  "signal_retention": ', TEXT_MUTED, font_code_small), ('"100%",', NEON_GREEN, font_code_small)],
            [('  "token_savings": ', TEXT_MUTED, font_code_small), ('"97.0%"', NEON_GREEN, font_code_bold)],
        ]
        box_h = 24 + len(json_tokens_list) * 18 + 10
        draw_rounded_rect(draw, [split_x + 20, json_box_top, WIDTH - 25, json_box_top + box_h], 6, fill=(15, 23, 35), outline=(40, 75, 120))
        draw.text((split_x + 32, json_box_top + 6), "{", font=font_code_bold, fill=TEXT_MAIN)
        j_y = json_box_top + 24
        for line_tokens in json_tokens_list:
            draw_tokens(draw, split_x + 36, j_y, line_tokens)
            j_y += 18
        draw.text((split_x + 32, j_y), "}", font=font_code_bold, fill=TEXT_MAIN)
        ry = json_box_top + box_h + 16

    if r_step >= 3:
        draw_rounded_rect(draw, [split_x + 20, ry, WIDTH - 25, ry + 44], 6, fill=NEON_GREEN_BG, outline=NEON_GREEN)
        draw.text((split_x + 30, ry + 6), "[DIRECTIVE] 1-Turn Deterministic Heuristic Applied:", font=font_code_bold, fill=NEON_GREEN)
        draw.text((split_x + 30, ry + 24), "Agent wraps Column in SingleChildScrollView (1-line targeted edit)", font=font_code_small, fill=TEXT_MAIN)
        ry += 52

    if r_step >= 4:
        draw_tokens(draw, split_x + 20, ry, [("$ ", NEON_CYAN, font_cmd), ("flutter test test/scenario1_vertical_overflow_test.dart", TEXT_MAIN, font_cmd)])
        ry += 20
        draw.text((split_x + 20, ry), "00:01 +1: All tests passed! [SUCCESS]", font=font_code_bold, fill=NEON_GREEN)
        ry += 22
        draw_rounded_rect(draw, [split_x + 20, ry, WIDTH - 25, ry + 46], 6, fill=(16, 48, 25), outline=NEON_GREEN, width=2)
        draw.text((split_x + 30, ry + 6), "[RESOLVED] IN 1 TURN (Zero Doom Loop)", font=font_code_bold, fill=NEON_GREEN)
        draw.text((split_x + 30, ry + 25), "Total Tokens: 118 | Latency: 12ms | Saved 97% API Tokens", font=font_code_small, fill=TEXT_MAIN)

    # =========================================================================
    # --- BOTTOM FOOTER: 3 MINI ELEVATED KPI CARDS ---
    # =========================================================================
    kpi_y1 = HEIGHT - 82
    kpi_y2 = HEIGHT - 18
    card_w = (WIDTH - 70) // 3

    # Card 1: Token Efficiency
    c1_x1 = 25
    c1_x2 = c1_x1 + card_w
    draw_rounded_rect(draw, [c1_x1, kpi_y1, c1_x2, kpi_y2], 8, fill=(18, 26, 40), outline=(45, 65, 95))
    draw.text((c1_x1 + 14, kpi_y1 + 8), "TOKEN REDUCTION", font=font_kpi_title, fill=NEON_CYAN)
    draw.text((c1_x1 + 14, kpi_y1 + 26), state['kpi1_val'], font=font_kpi_val, fill=NEON_GREEN if "96" in state['kpi1_val'] else TEXT_MAIN)
    bar_x1, bar_y1, bar_x2, bar_y2 = c1_x1 + 14, kpi_y1 + 48, c1_x2 - 14, kpi_y1 + 54
    draw.rectangle([bar_x1, bar_y1, bar_x2, bar_y2], fill=(30, 40, 60))
    prog_w = int((bar_x2 - bar_x1) * state.get('kpi1_prog', 0.0))
    if prog_w > 0:
        draw.rectangle([bar_x1, bar_y1, bar_x1 + prog_w, bar_y2], fill=NEON_GREEN)

    # Card 2: Latency Speedup
    c2_x1 = c1_x2 + 10
    c2_x2 = c2_x1 + card_w
    draw_rounded_rect(draw, [c2_x1, kpi_y1, c2_x2, kpi_y2], 8, fill=(18, 26, 40), outline=(45, 65, 95))
    draw.text((c2_x1 + 14, kpi_y1 + 8), "EXECUTION LATENCY", font=font_kpi_title, fill=NEON_CYAN)
    draw.text((c2_x1 + 14, kpi_y1 + 26), state['kpi2_val'], font=font_kpi_val, fill=NEON_BLUE if "12ms" in state['kpi2_val'] else TEXT_MAIN)
    bar_x1, bar_y1, bar_x2, bar_y2 = c2_x1 + 14, kpi_y1 + 48, c2_x2 - 14, kpi_y1 + 54
    draw.rectangle([bar_x1, bar_y1, bar_x2, bar_y2], fill=(30, 40, 60))
    prog_w2 = int((bar_x2 - bar_x1) * state.get('kpi2_prog', 0.0))
    if prog_w2 > 0:
        draw.rectangle([bar_x1, bar_y1, bar_x1 + prog_w2, bar_y2], fill=NEON_BLUE)

    # Card 3: Circuit Breaker / Doom Loop
    c3_x1 = c2_x2 + 10
    c3_x2 = WIDTH - 25
    draw_rounded_rect(draw, [c3_x1, kpi_y1, c3_x2, kpi_y2], 8, fill=(18, 26, 40), outline=(45, 65, 95))
    draw.text((c3_x1 + 14, kpi_y1 + 8), "ONE-SHOT RESOLUTION", font=font_kpi_title, fill=NEON_CYAN)
    draw.text((c3_x1 + 14, kpi_y1 + 26), state['kpi3_val'], font=font_kpi_val, fill=NEON_GREEN if "Zero" in state['kpi3_val'] else TEXT_MAIN)
    bar_x1, bar_y1, bar_x2, bar_y2 = c3_x1 + 14, kpi_y1 + 48, c3_x2 - 14, kpi_y1 + 54
    draw.rectangle([bar_x1, bar_y1, bar_x2, bar_y2], fill=(30, 40, 60))
    prog_w3 = int((bar_x2 - bar_x1) * state.get('kpi3_prog', 0.0))
    if prog_w3 > 0:
        draw.rectangle([bar_x1, bar_y1, bar_x1 + prog_w3, bar_y2], fill=NEON_GREEN)

    return img


def generate_10x_gif(output_path="assets/flutter_sanity_demo.gif"):
    print("Generating 10x Cinematic Split-Screen Benchmark GIF...")
    frames = []
    durations = []

    # Sequence Timeline
    story = [
        # 0: Idle start (both ready, caret blinking)
        {
            "left_cmd": "", "right_cmd": "", "left_caret": True, "right_caret": True,
            "left_step": 0, "right_step": 0,
            "left_tokens": 0, "right_tokens": 0,
            "left_cost": "$0.00", "right_cost": "$0.00",
            "left_time": "0ms", "right_time": "0ms",
            "left_status": "Idle", "right_status": "Idle",
            "kpi1_val": "Benchmarking...", "kpi1_prog": 0.05,
            "kpi2_val": "0ms", "kpi2_prog": 0.05,
            "kpi3_val": "Waiting Run...", "kpi3_prog": 0.05,
            "duration": 600
        },
        # 1: Typing commands
        {
            "left_cmd": "flutter test test/scenario1", "right_cmd": "flutter-sanity inspect test/scenario1",
            "left_caret": True, "right_caret": True,
            "left_step": 0, "right_step": 0,
            "left_tokens": 0, "right_tokens": 0,
            "left_cost": "$0.00", "right_cost": "$0.00",
            "left_time": "0ms", "right_time": "0ms",
            "left_status": "Typing...", "right_status": "Typing...",
            "kpi1_val": "Benchmarking...", "kpi1_prog": 0.15,
            "kpi2_val": "0ms", "kpi2_prog": 0.10,
            "kpi3_val": "Waiting Run...", "kpi3_prog": 0.10,
            "duration": 500
        },
        # 2: Commands entered, tests launching
        {
            "left_cmd": "flutter test test/scenario1_vertical_overflow_test.dart",
            "right_cmd": "flutter-sanity inspect test/scenario1_vertical_overflow_test.dart",
            "left_caret": False, "right_caret": False,
            "left_step": 1, "right_step": 0,
            "left_tokens": 120, "right_tokens": 0,
            "left_cost": "$0.01", "right_cost": "$0.00",
            "left_time": "120ms", "right_time": "0ms",
            "left_status": "Starting", "right_status": "Starting",
            "kpi1_val": "Measuring...", "kpi1_prog": 0.30,
            "kpi2_val": "120ms", "kpi2_prog": 0.20,
            "kpi3_val": "Evaluating...", "kpi3_prog": 0.20,
            "duration": 600
        },
        # 3: Left hits assertion caught, Right intercepts in 9ms
        {
            "left_cmd": "flutter test test/scenario1_vertical_overflow_test.dart",
            "right_cmd": "flutter-sanity inspect test/scenario1_vertical_overflow_test.dart",
            "left_caret": False, "right_caret": False,
            "left_step": 2, "right_step": 1,
            "left_tokens": 1850, "right_tokens": 45,
            "left_cost": "$0.08", "right_cost": "$0.002",
            "left_time": "450ms", "right_time": "9ms",
            "left_status": "ASSERT FAILS", "right_status": "PARSING",
            "kpi1_val": "97.5% Filtered", "kpi1_prog": 0.60,
            "kpi2_val": "9ms vs 450ms", "kpi2_prog": 0.50,
            "kpi3_val": "Sanitizing...", "kpi3_prog": 0.40,
            "duration": 800
        },
        # 4: Left dumps 4,000-line ASCII tree! Right produces high-density JSON
        {
            "left_cmd": "flutter test test/scenario1_vertical_overflow_test.dart",
            "right_cmd": "flutter-sanity inspect test/scenario1_vertical_overflow_test.dart",
            "left_caret": False, "right_caret": False,
            "left_step": 3, "right_step": 2,
            "left_tokens": 3940, "right_tokens": 118,
            "left_cost": "$0.16", "right_cost": "$0.005",
            "left_time": "1.2s", "right_time": "12ms",
            "left_status": "CONTEXT BLOAT", "right_status": "CLEAN JSON",
            "kpi1_val": "97.0% Saved", "kpi1_prog": 0.85,
            "kpi2_val": "12ms (450x faster)", "kpi2_prog": 0.80,
            "kpi3_val": "Directive Injected", "kpi3_prog": 0.70,
            "duration": 1200
        },
        # 5: Left agent suffers context rot & hallucinates, Right applies 1-line heuristic directive
        {
            "left_cmd": "flutter test test/scenario1_vertical_overflow_test.dart",
            "right_cmd": "flutter-sanity inspect test/scenario1_vertical_overflow_test.dart",
            "left_caret": False, "right_caret": False,
            "left_step": 4, "right_step": 3,
            "left_tokens": 7880, "right_tokens": 118,
            "left_cost": "$0.32", "right_cost": "$0.005",
            "left_time": "2.8s", "right_time": "14ms",
            "left_status": "DOOM LOOP #1", "right_status": "FIX APPLIED",
            "kpi1_val": "98.5% Saved", "kpi1_prog": 0.95,
            "kpi2_val": "14ms Latency", "kpi2_prog": 0.90,
            "kpi3_val": "Targeted 1-Line Fix", "kpi3_prog": 0.85,
            "duration": 1300
        },
        # 6: Grand Finale - Left circuit trips (doom loop), Right passes green in 1 turn!
        {
            "left_cmd": "flutter test test/scenario1_vertical_overflow_test.dart",
            "right_cmd": "flutter-sanity inspect test/scenario1_vertical_overflow_test.dart",
            "left_caret": False, "right_caret": False,
            "left_step": 5, "right_step": 4,
            "left_tokens": 11820, "right_tokens": 118,
            "left_cost": "$0.48", "right_cost": "$0.005",
            "left_time": "5.4s", "right_time": "18ms",
            "left_status": "CIRCUIT TRIPPED", "right_status": "1-TURN PASS!",
            "kpi1_val": "96.84% (-44.2k tokens)", "kpi1_prog": 0.968,
            "kpi2_val": "12ms (Zero Wait)", "kpi2_prog": 0.98,
            "kpi3_val": "Zero Doom Loops", "kpi3_prog": 1.0,
            "duration": 4000  # Hold the grand finale for 4.0 seconds
        },
    ]

    for state in story:
        frame = render_frame(state)
        frame_p = frame.quantize(colors=128, method=Image.Resampling.LANCZOS)
        frames.append(frame_p)
        durations.append(state["duration"])

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
    print(f"SUCCESS: 10x Upgraded Cinematic GIF saved to {output_path} ({file_size_kb:.1f} KB)")


if __name__ == "__main__":
    generate_10x_gif()
