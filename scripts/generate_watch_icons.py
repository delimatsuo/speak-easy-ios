#!/usr/bin/env python3
"""
Apple Watch Icon Generator
Creates circular watch icons from the square iOS design
"""

import os
from PIL import Image, ImageDraw, ImageFilter
import math

def create_gradient_background(size, start_color, end_color):
    """Create a radial gradient background"""
    image = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    
    # Create radial gradient from center
    center_x, center_y = size // 2, size // 2
    max_radius = size // 2
    
    for r in range(max_radius):
        # Calculate gradient ratio
        ratio = r / max_radius
        
        # Interpolate colors
        r_val = int(start_color[0] * (1 - ratio) + end_color[0] * ratio)
        g_val = int(start_color[1] * (1 - ratio) + end_color[1] * ratio)
        b_val = int(start_color[2] * (1 - ratio) + end_color[2] * ratio)
        
        color = (r_val, g_val, b_val, 255)
        
        # Draw circle at current radius
        bbox = [center_x - r, center_y - r, center_x + r, center_y + r]
        draw.ellipse(bbox, fill=color)
    
    return image

def create_profile_silhouette(size):
    """Create the profile silhouette"""
    image = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    
    # Scale factor for the design elements
    scale = size / 1024.0
    
    # Profile silhouette coordinates (scaled from original)
    profile_points = [
        (int(120 * scale), int(80 * scale)),   # Top of head
        (int(180 * scale), int(60 * scale)),   # Forehead
        (int(220 * scale), int(100 * scale)),  # Brow
        (int(230 * scale), int(140 * scale)),  # Eye area
        (int(240 * scale), int(180 * scale)),  # Nose bridge
        (int(250 * scale), int(220 * scale)),  # Nose tip
        (int(245 * scale), int(260 * scale)),  # Upper lip
        (int(240 * scale), int(290 * scale)),  # Mouth
        (int(235 * scale), int(320 * scale)),  # Lower lip
        (int(220 * scale), int(360 * scale)),  # Chin
        (int(200 * scale), int(400 * scale)),  # Jaw
        (int(180 * scale), int(450 * scale)),  # Neck
        (int(160 * scale), int(500 * scale)),  # Shoulder
        (int(50 * scale), int(520 * scale)),   # Back of neck
        (int(40 * scale), int(480 * scale)),   # Back of head curve
        (int(35 * scale), int(400 * scale)),   # Back of head
        (int(40 * scale), int(300 * scale)),   # Crown
        (int(60 * scale), int(200 * scale)),   # Top back
        (int(90 * scale), int(120 * scale)),   # Top curve
    ]
    
    # Create smooth silhouette
    draw.polygon(profile_points, fill=(255, 255, 255, 200))
    
    return image

def create_sound_waves(size):
    """Create the sound wave elements"""
    image = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    draw = ImageDraw.Draw(image)
    
    # Scale factor
    scale = size / 1024.0
    
    # Sound wave parameters
    center_x = int(size * 0.7)  # Position waves to the right
    center_y = int(size * 0.45)  # Vertically centered around mouth area
    
    # Wave thicknesses and positions
    waves = [
        {'radius': int(80 * scale), 'thickness': int(12 * scale)},
        {'radius': int(120 * scale), 'thickness': int(14 * scale)},
        {'radius': int(160 * scale), 'thickness': int(16 * scale)},
        {'radius': int(200 * scale), 'thickness': int(18 * scale)},
    ]
    
    for wave in waves:
        radius = wave['radius']
        thickness = wave['thickness']
        
        # Create arc for sound wave (right side only)
        bbox = [center_x - radius, center_y - radius, center_x + radius, center_y + radius]
        
        # Draw multiple overlapping arcs to create thickness
        for i in range(thickness):
            draw.arc(bbox, start=-45, end=45, fill=(255, 255, 255, 180), width=2)
            bbox = [bbox[0] + 1, bbox[1] + 1, bbox[2] - 1, bbox[3] - 1]
    
    return image

def create_circular_watch_icon(size):
    """Create a circular Apple Watch icon"""
    # Create base circular image
    icon = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    
    # Create gradient background (teal to green)
    gradient = create_gradient_background(size, (102, 204, 204), (0, 128, 128))
    
    # Create profile silhouette
    profile = create_profile_silhouette(size)
    
    # Create sound waves
    waves = create_sound_waves(size)
    
    # Composite all elements
    icon = Image.alpha_composite(icon, gradient)
    icon = Image.alpha_composite(icon, profile)
    icon = Image.alpha_composite(icon, waves)
    
    # Create circular mask
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse([0, 0, size, size], fill=255)
    
    # Apply circular mask
    output = Image.new('RGBA', (size, size), (255, 255, 255, 0))
    output.paste(icon, (0, 0))
    output.putalpha(mask)
    
    return output

def main():
    """Generate all Apple Watch icon sizes"""
    
    # Create output directory
    output_dir = '/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/watchOS/WatchAssets.xcassets/AppIcon.appiconset'
    os.makedirs(output_dir, exist_ok=True)
    
    # Icon sizes and filenames as specified in Contents.json
    icon_specs = [
        (48, 'AppIcon-24@2x.png'),      # 24x24 @2x
        (55, 'AppIcon-27.5@2x.png'),    # 27.5x27.5 @2x  
        (58, 'AppIcon-29@2x.png'),      # 29x29 @2x
        (87, 'AppIcon-29@3x.png'),      # 29x29 @3x
        (66, 'AppIcon-33@2x.png'),      # 33x33 @2x
        (80, 'AppIcon-40@2x.png'),      # 40x40 @2x
        (88, 'AppIcon-44@2x.png'),      # 44x44 @2x
        (92, 'AppIcon-46@2x.png'),      # 46x46 @2x
        (100, 'AppIcon-50@2x.png'),     # 50x50 @2x
        (102, 'AppIcon-51@2x.png'),     # 51x51 @2x
        (108, 'AppIcon-54@2x.png'),     # 54x54 @2x
        (172, 'AppIcon-86@2x.png'),     # 86x86 @2x
        (196, 'AppIcon-98@2x.png'),     # 98x98 @2x
        (216, 'AppIcon-108@2x.png'),    # 108x108 @2x
        (234, 'AppIcon-117@2x.png'),    # 117x117 @2x
        (258, 'AppIcon-129@2x.png'),    # 129x129 @2x
        (1024, 'AppIcon-1024.png'),     # 1024x1024 marketing
    ]
    
    print("Generating Apple Watch icons...")
    
    for size, filename in icon_specs:
        print(f"Creating {filename} ({size}x{size})")
        
        # Create icon
        icon = create_circular_watch_icon(size)
        
        # Save icon
        filepath = os.path.join(output_dir, filename)
        icon.save(filepath, 'PNG')
        
        print(f"✓ Saved {filepath}")
    
    print("\n🎉 All Apple Watch icons generated successfully!")
    print(f"Icons saved to: {output_dir}")

if __name__ == '__main__':
    main()