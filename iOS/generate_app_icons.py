#!/usr/bin/env python3

import os
from PIL import Image, ImageDraw
import numpy as np

def create_gradient(width, height):
    """Create a blue to teal gradient background"""
    # Colors from the SwiftUI code
    color1 = (0, 153, 102)  # RGB for (0.00, 0.60, 0.40)
    color2 = (0, 102, 191)  # RGB for (0.00, 0.40, 0.75)
    
    # Create gradient
    gradient = np.zeros((height, width, 3), dtype=np.uint8)
    for y in range(height):
        for x in range(width):
            # Calculate gradient factor based on position (bottom-right to top-left)
            factor = ((x / width) + (y / height)) / 2
            r = int(color1[0] * (1 - factor) + color2[0] * factor)
            g = int(color1[1] * (1 - factor) + color2[1] * factor)
            b = int(color1[2] * (1 - factor) + color2[2] * factor)
            gradient[y, x] = [r, g, b]
    
    return Image.fromarray(gradient)

def draw_face_silhouette(draw, rect, color):
    """Draw a stylized face silhouette"""
    x, y, w, h = rect
    
    # Create points for the face profile
    points = [
        (x + w * 0.95, y + h * 0.15),  # Forehead
        (x + w * 0.85, y + h * 0.10),  # Top curve
        (x + w * 0.70, y + h * 0.20),  # Above nose
        (x + w * 0.60, y + h * 0.35),  # Nose bridge
        (x + w * 0.50, y + h * 0.40),  # Nose tip
        (x + w * 0.45, y + h * 0.45),  # Below nose
        (x + w * 0.40, y + h * 0.48),  # Upper lip
        (x + w * 0.35, y + h * 0.50),  # Mouth
        (x + w * 0.30, y + h * 0.52),  # Lower lip
        (x + w * 0.15, y + h * 0.55),  # Chin
        (x + w * 0.10, y + h * 0.65),  # Under chin
        (x + w * 0.20, y + h * 0.75),  # Neck
        (x + w * 0.40, y + h * 0.85),  # Back of head bottom
        (x + w * 0.70, y + h * 0.90),  # Back curve
        (x + w * 0.95, y + h * 0.85),  # Back of head
        (x + w * 0.95, y + h * 0.15),  # Back to start
    ]
    
    draw.polygon(points, fill=color)

def draw_sound_waves(draw, rect, color, line_width, count=3):
    """Draw concentric arc sound waves"""
    x, y, w, h = rect
    center_x = x + line_width // 2
    center_y = y + h // 2
    
    for i in range(count):
        radius = int((i + 1) / count * (w // 2 - line_width))
        # Draw arc from -45 to 45 degrees
        bbox = [
            center_x - radius,
            center_y - radius,
            center_x + radius,
            center_y + radius
        ]
        draw.arc(bbox, start=-45, end=45, fill=color, width=line_width)

def create_app_icon(size):
    """Create the Speak Easy app icon at the specified size"""
    # Create base image with gradient
    img = create_gradient(size, size)
    
    # Create drawing context with antialiasing
    draw = ImageDraw.Draw(img, 'RGBA')
    
    # Add rounded corners (20% of size)
    corner_radius = int(size * 0.2)
    
    # Create mask for rounded corners
    mask = Image.new('L', (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle([0, 0, size, size], corner_radius, fill=255)
    
    # Apply mask to create rounded corners
    output = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    output.paste(img, (0, 0))
    output.putalpha(mask)
    
    # Recreate image with background
    final = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    final.paste(output, (0, 0), output)
    
    # Draw on the final image
    draw = ImageDraw.Draw(final)
    
    # Draw face silhouette (30% width, 80% height, offset left by 20%)
    face_rect = (
        int(size * 0.05),  # x position (shifted from -20% to account for width)
        int(size * 0.10),  # y position (10% from top)
        int(size * 0.30),  # width
        int(size * 0.80)   # height
    )
    draw_face_silhouette(draw, face_rect, 'white')
    
    # Draw sound waves (50% width, 80% height, offset right by 10%)
    wave_rect = (
        int(size * 0.35),  # x position
        int(size * 0.10),  # y position
        int(size * 0.50),  # width
        int(size * 0.80)   # height
    )
    line_width = int(size * 0.04)
    draw_sound_waves(draw, wave_rect, 'white', line_width, 3)
    
    return final

# Icon sizes to generate
icon_sizes = [
    ("AppIcon-20@1x", 20),
    ("AppIcon-20@2x", 40),
    ("AppIcon-20@3x", 60),
    ("AppIcon-29@1x", 29),
    ("AppIcon-29@2x", 58),
    ("AppIcon-29@3x", 87),
    ("AppIcon-40@1x", 40),
    ("AppIcon-40@2x", 80),
    ("AppIcon-40@3x", 120),
    ("AppIcon-60@2x", 120),
    ("AppIcon-60@3x", 180),
    ("AppIcon-76@1x", 76),
    ("AppIcon-76@2x", 152),
    ("AppIcon-83.5@2x", 167),
    ("AppIcon-1024@1x", 1024)
]

# Create output directory
output_dir = "/Users/delimatsuo/Documents/Codingclaude/UniversalTranslatorApp/iOS/AppIcons"
os.makedirs(output_dir, exist_ok=True)

print("Generating Speak Easy app icons...")
for name, size in icon_sizes:
    icon = create_app_icon(size)
    filepath = os.path.join(output_dir, f"{name}.png")
    icon.save(filepath, "PNG")
    print(f"Generated {name}.png ({size}x{size})")

print(f"\nDone! All icons generated in '{output_dir}' directory.")
print("\nTo use these icons:")
print("1. Open your Xcode project")
print("2. Select Assets.xcassets")
print("3. Select AppIcon")
print("4. Drag and drop the generated icons to their corresponding slots")