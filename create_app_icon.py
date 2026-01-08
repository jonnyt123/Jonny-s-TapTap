#!/usr/bin/env python3
"""Generate an app icon for Jonny's Tap Tap with lightning bolts and Metallica-style font."""

from PIL import Image, ImageDraw, ImageFont
import math

# Icon dimensions (iOS standard)
size = 1024
half = size // 2

# Create image with medium grey background for better contrast with black text
img = Image.new('RGB', (size, size), color=(140, 140, 140))
draw = ImageDraw.Draw(img, 'RGBA')

# Draw lightning bolts in white
lightning_blue = (255, 255, 255, 255)

def draw_lightning_bolt(draw, start_x, start_y, length, angle, width=20):
    """Draw a lightning bolt using jagged lines."""
    points = []
    x, y = start_x, start_y
    points.append((x, y))
    
    # Create jagged lightning path
    segments = 5
    for i in range(segments):
        # Random offset for jagged effect
        offset_x = (i % 2) * 30 - 15
        x += length / segments * math.cos(angle) + offset_x
        y += length / segments * math.sin(angle) + (length / segments * 0.3)
        points.append((x, y))
    
    # Draw the lightning with thick lines
    for i in range(len(points) - 1):
        draw.line([points[i], points[i + 1]], fill=lightning_blue, width=width)

# Draw 3 lightning bolts around the design
# Left lightning bolt
draw_lightning_bolt(draw, 150, 200, 300, math.pi * 0.3, width=25)

# Right lightning bolt
draw_lightning_bolt(draw, 874, 200, 300, math.pi * 0.7, width=25)

# Center lightning bolt (vertical)
draw_lightning_bolt(draw, 512, 150, 350, math.pi * 0.5, width=20)

# Add decorative lightning accents at bottom
draw.polygon([(250, 800), (280, 900), (320, 800), (290, 850)], fill=lightning_blue)
draw.polygon([(704, 800), (734, 900), (774, 800), (744, 850)], fill=lightning_blue)

# Load the provided Jonny's Tap Tap font (Metallica-style)
font_path = "/Users/jonny/RhythmTap/RhythmTap/Resources/Fonts/JonnysTapTap.ttf"
try:
    font = ImageFont.truetype(font_path, 180)
    font_bold = font
except Exception:
    # Fallback to system bold if the custom font cannot be loaded
    font = ImageFont.truetype("/System/Library/Fonts/Helvetica.ttc", 180)
    font_bold = font

# Add text "JONNY'S" on top
text1 = "JONNY'S"
bbox1 = draw.textbbox((0, 0), text1, font=font)
text1_width = bbox1[2] - bbox1[0]
x1 = (size - text1_width) // 2
draw.text((x1, 280), text1, fill=(0, 0, 0), font=font)

# Add text "TAP TAP" below
text2 = "TAP TAP"
bbox2 = draw.textbbox((0, 0), text2, font=font)
text2_width = bbox2[2] - bbox2[0]
x2 = (size - text2_width) // 2
draw.text((x2, 520), text2, fill=(0, 0, 0), font=font)

# Add subtle lightning accents around text for extra flair
accent_color = (255, 255, 255, 180)
draw.line([(80, 350), (120, 380)], fill=accent_color, width=8)
draw.line([(904, 350), (944, 380)], fill=accent_color, width=8)

# Save the icon
output_path = "/Users/jonny/RhythmTap/RhythmTap/Resources/AppIcon.png"
img.save(output_path)
print(f"✅ App icon created: {output_path}")
print(f"   Dimensions: {size}x{size}px")
print("   Design: Light blue lightning bolts, light grey background, black text")
