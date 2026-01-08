#!/usr/bin/env python3
"""
Setup app icon from source image
Generates all required iOS app icon sizes from a single source image
"""

from PIL import Image
import os

def setup_app_icon():
    """Generate app icons in all required sizes"""
    
    # Source image - should be at least 1024x1024
    source_image_path = "app_icon_source.png"
    
    if not os.path.exists(source_image_path):
        print(f"Error: {source_image_path} not found")
        print("Please save your app icon image as 'app_icon_source.png' in the project root")
        return
    
    # Open source image
    img = Image.open(source_image_path)
    print(f"Loaded source image: {img.size}")
    
    # Ensure image is RGB (not RGBA) for better compatibility
    if img.mode == 'RGBA':
        # Create white background
        background = Image.new('RGB', img.size, (255, 255, 255))
        background.paste(img, mask=img.split()[3])  # Use alpha channel as mask
        img = background
    elif img.mode != 'RGB':
        img = img.convert('RGB')
    
    # Icon sizes required for iOS (size@multiplier -> pixel size)
    icon_sizes = [
        (20, 1, "20"),      # iPhone notification (2x/3x: 40x40, 60x60)
        (20, 2, "20@2x"),
        (20, 3, "20@3x"),
        (29, 1, "29"),      # iPhone settings (2x/3x: 58x58, 87x87)
        (29, 2, "29@2x"),
        (29, 3, "29@3x"),
        (40, 1, "40"),      # iPhone spotlight (2x/3x: 80x80, 120x120)
        (40, 2, "40@2x"),
        (40, 3, "40@3x"),
        (60, 2, "60@2x"),   # iPhone app icon (2x/3x: 120x120, 180x180)
        (60, 3, "60@3x"),
        (1024, 1, "1024"),  # App store icon
    ]
    
    icon_dir = "Resources/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(icon_dir, exist_ok=True)
    
    print(f"\nGenerating app icons in {icon_dir}...")
    
    for base_size, multiplier, name in icon_sizes:
        size = base_size * multiplier
        
        # Resize image using high-quality resampling
        resized = img.resize((size, size), Image.Resampling.LANCZOS)
        
        # Save icon
        output_path = os.path.join(icon_dir, f"icon-{name}.png")
        resized.save(output_path, 'PNG', quality=95)
        
        print(f"✓ Generated {size}x{size} icon: icon-{name}.png")
    
    print("\n✅ All app icons generated successfully!")
    print("Your icons are ready in Resources/Assets.xcassets/AppIcon.appiconset/")

if __name__ == "__main__":
    setup_app_icon()
