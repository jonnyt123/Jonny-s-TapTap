#!/usr/bin/env python3
"""Generate app icons from the provided image."""

from PIL import Image
import os

# Image sizes needed for iOS
icon_sizes = [
    (40, "icon-20@2x.png"),      # 20x20 @2x
    (60, "icon-20@3x.png"),      # 20x20 @3x
    (58, "icon-29@2x.png"),      # 29x29 @2x
    (87, "icon-29@3x.png"),      # 29x29 @3x
    (80, "icon-40@2x.png"),      # 40x40 @2x
    (120, "icon-40@3x.png"),     # 40x40 @3x
    (120, "icon-60@2x.png"),     # 60x60 @2x
    (180, "icon-60@3x.png"),     # 60x60 @3x
    (1024, "icon-1024.png"),     # iOS App Store
]

# Open the source image
source_image = Image.open("appicon.png")

# Output directory
output_dir = "Resources/Assets.xcassets/AppIcon.appiconset"
os.makedirs(output_dir, exist_ok=True)

# Generate each size
for size, filename in icon_sizes:
    # Resize maintaining aspect ratio by fitting into square
    img = source_image.copy()
    img.thumbnail((size, size), Image.Resampling.LANCZOS)
    
    # Create square canvas and paste centered
    final_img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    offset = ((size - img.size[0]) // 2, (size - img.size[1]) // 2)
    final_img.paste(img, offset, img if img.mode == "RGBA" else None)
    
    # Save
    output_path = os.path.join(output_dir, filename)
    final_img.save(output_path, "PNG")
    print(f"Created {filename} ({size}x{size})")

print("Icon generation complete!")
