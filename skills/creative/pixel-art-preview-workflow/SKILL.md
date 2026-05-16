---
name: pixel-art-preview-workflow
description: Generate pixel art characters using Python PIL and preview via Discord. Use when creating game-like visualizations, character sprites, or any pixel art that needs user feedback via Discord.
version: 1.0.0
author: Hermes Developer
license: MIT
metadata:
  category: creative
  tools: [python-pillow, discord-send-file]
  inputs: [character-design-requirements]
  outputs: [sprite-sheets, individual-sprites, discord-preview]
---

# Pixel Art Preview Workflow

## Overview

Generate pixel art character sprites using Python PIL and preview them via Discord for user feedback. This workflow combines programmatic pixel art generation with Discord as a rapid feedback loop.

## When to Use

- Creating game-like visualizations with character avatars
- Generating pixel art sprites for web portals or dashboards
- When user needs to approve visual style before committing to full implementation
- Rapid iteration on pixel art designs (test → feedback → modify → retest)

## Prerequisites

```python
# Required Python packages
from PIL import Image
import json
```

## Core Pattern

### 1. Define Color Palettes

```python
# Group colors by role/hair/shirt/pants for consistency
SKIN_LIGHT = (255, 220, 200)
SKIN_PINK = (255, 180, 170)
BLUSH = (255, 150, 150)

HAIR = {
    'orchestrator': [(150, 100, 180), (120, 80, 150)],
    'designer': [(255, 150, 200), (255, 100, 180)],
    # ...
}

SHIRT = { ... }
PANTS = { ... }
```

### 2. Core Drawing Functions

```python
def pixel(img, x, y, c, alpha=255):
    """Set single pixel with optional transparency"""
    if 0 <= x < img.width and 0 <= y < img.height:
        if alpha < 255:
            e = img.getpixel((x, y))
            c = (int(e[0]*(1-alpha/255)+c[0]*alpha/255), ...)
        img.putpixel((x, y), c)

def rect(img, x, y, w, h, c):
    """Draw filled rectangle"""
    for dy in range(h):
        for dx in range(w):
            pixel(img, x+dx, y+dy, c)

def circle(img, cx, cy, r, c):
    """Draw filled circle using midpoint algorithm"""
    for y in range(-r, r+1):
        for x in range(-r, r+1):
            if x*x + y*y <= r*r:
                pixel(img, cx+x, cy+y, c)
```

### 3. Chibi Character Template (Cute Style - FRONT FACING Full Body)

For office visualization (David Chu's project): FRONT-FACING, FULL BODY with both hands and feet.

```python
def draw_chibi_full_body(img, ox, oy, hair_c, shirt_c, pants_c, skin=SKIN_LIGHT, eye_color=(60, 60, 80)):
    """Front-facing chibi with BOTH hands and BOTH feet"""
    shadow = (40, 30, 50, 100)
    
    # Shadow under BOTH feet
    for dx in range(-24, -8):
        pixel(img, ox+dx, oy+125, shadow)
    for dx in range(8, 24):
        pixel(img, ox+dx, oy+125, shadow)
    
    # BOTH legs
    rect(img, ox-18, oy+95, 14, 25, pants_c[0])  # LEFT leg
    rect(img, ox+4, oy+95, 14, 25, pants_c[1])    # RIGHT leg
    
    # BOTH shoes/feet
    rect(img, ox-22, oy+118, 16, 6, (80, 60, 50))  # LEFT foot
    rect(img, ox+6, oy+118, 16, 6, (80, 60, 50))   # RIGHT foot
    
    # Body (small - chibi proportion ~30% of height)
    rect(img, ox-22, oy+65, 44, 32, shirt_c[0])
    
    # BOTH arms
    rect(img, ox-32, oy+68, 12, 24, shirt_c[0])   # LEFT arm
    rect(img, ox+20, oy+68, 12, 24, shirt_c[1])   # RIGHT arm
    
    # BOTH hands (skin colored)
    rect(img, ox-32, oy+90, 10, 8, skin)   # LEFT hand
    rect(img, ox+22, oy+90, 10, 8, skin)   # RIGHT hand
    
    # Head (BIG - chibi style ~45% of height)
    rect(img, ox-30, oy+5, 60, 55, skin)
    
    # Hair (front-facing, covers top of head)
    rect(img, ox-30, oy, 60, 18, hair_c[0])
    
    # LARGE eyes (key to cuteness - 12-16px wide)
    rect(img, ox-22, oy+28, 16, 14, (255, 255, 255))  # LEFT eye white
    rect(img, ox+6, oy+28, 16, 14, (255, 255, 255))   # RIGHT eye white
    rect(img, ox-18, oy+32, 10, 8, eye_color)   # LEFT iris
    rect(img, ox+10, oy+32, 10, 8, eye_color)   # RIGHT iris
    
    # Eye shine (important for cuteness!)
    pixel(img, ox-16, oy+30, (255, 255, 255))  # LEFT shine
    pixel(img, ox+12, oy+30, (255, 255, 255))  # RIGHT shine
    
    # Blush (both sides symmetric)
    pixel(img, ox-26, oy+40, BLUSH, 120)
    pixel(img, ox+22, oy+40, BLUSH, 120)
    
    # Small smile
    pixel(img, ox-3, oy+47, (220, 100, 100))
    pixel(img, ox-1, oy+46, (220, 100, 100))
    pixel(img, ox+1, oy+47, (220, 100, 100))
```

### 4. Role-Specific Accessories

```python
def draw_accessory(img, key, ox, oy):
    if key == 'orchestrator':
        # Crown
        for dx in [-8, -4, 0, 4, 8]:
            rect(img, ox+dx-2, oy-18, 4, 12, (255, 215, 0))
        rect(img, ox-12, oy-8, 24, 6, (255, 215, 0))
        # Magic wand
        rect(img, ox+30, oy+30, 4, 40, (200, 160, 100))
        circle(img, ox+32, oy+26, 8, (255, 255, 150))
```

### 5. Sprite Sheet Generation

```python
def create_character(key, size=128):
    """Create single character sprite"""
    img = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    # ... draw character ...
    return img

# Generate sprite sheet
sprite_size = 128
spacing = 8
cols = 7
characters = ['orchestrator', 'ceo', 'designer', ...]

sheet_w = cols * (sprite_size + spacing)
sheet_h = 2 * (sprite_size + spacing)
sheet = Image.new('RGBA', (sheet_w, sheet_h), (0, 0, 0, 0))

for i, key in enumerate(characters):
    row = i // cols
    col = i % cols
    x = col * (sprite_size + spacing)
    y = row * (sprite_size + spacing)
    sheet.paste(create_character(key), (x, y))

sheet.save('assets/sprite-sheet-128.png')
```

## Discord Preview

### Sending Images to Discord

Use `send_message` with `MEDIA:` prefix:

```python
# Correct format
send_message(
    action="send",
    target="discord:#developer",  # or specific channel
    message="MEDIA:/home/user/project/assets/character.png\nDescription"
)
```

**Important:**
- Use absolute path after `MEDIA:`
- Path must exist on the machine running Hermes
- Works with PNG, JPG, GIF

### Workflow

```
1. Generate pixel art → save to ~/projects/project/assets/
2. Send to Discord with description
3. User reviews and gives feedback
4. Modify generation code if needed
5. Regenerate and resend
6. Repeat until approved
```

## Iterative Feedback Patterns (David Chu)

When generating sprites for David's subagent visualization projects, expect these feedback patterns:

| Feedback | Meaning | Fix |
|----------|---------|-----|
| "太抽象" / no face | Character lacks identifiable facial features | Add large eyes (big = cute), small nose, tiny smile, blush marks |
| "半邊人" / half body | Only partial body shown | Draw full body: head + torso + BOTH arms + BOTH legs + BOTH feet |
| 正面 (front-facing) | Character shown in profile/3q view | Redesign all coordinates for direct front-facing view |
| Too small | 16x16 or 32x32 too small for intended use | Scale up to 64x64 minimum, 128x128 for web portal display |
| Not cute enough | Body proportions too realistic | Use chibi proportions: BIG head (40% of height), small body, stubby limbs |

**Key lesson**: David Chu's office visualization needs FRONT-FACING, FULL-BODY characters with BOTH hands and BOTH feet visible. Not half-body, not profile view.

## Common Issues

| Issue | Solution |
|-------|----------|
| Typos in drawing functions | `y_out` should be `y_off` — check all variable names |
| Image too small | Scale up using `img.resize((size, size), Image.NEAREST)` for pixelated look |
| Colors wrong | Ensure RGBA mode and correct tuple format `(R, G, B)` or `(R, G, B, A)` |
| Discord shows no image | Use absolute path with `MEDIA:` prefix |
| Character looks "half" | Draw complete bilateral symmetry — two arms, two legs, two feet |
| Eyes not expressive | Make eyes LARGE (12-16px wide for 128x128), add shine pixel + iris color |

## Verification

After generating, verify with:

```python
from PIL import Image
img = Image.open('assets/character_128.png')
print(f"Size: {img.size}, Mode: {img.mode}")  # Should be (128, 128), RGBA
```

## File Structure

```
project/
├── generate_pixels.py      # Main generation script
├── assets/
│   ├── characters/
│   │   ├── sprite-sheet-128.png
│   │   ├── sprite-metadata.json
│   │   └── {character}_128.png  # Individual sprites
│   └── room-icons/
└── SPEC.md
```