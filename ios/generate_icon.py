import math
from PIL import Image, ImageDraw, ImageFilter

def create_app_icon(output_path="ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png"):
    size = 1024
    img = Image.new("RGB", (size, size), (10, 12, 18))
    draw = ImageDraw.Draw(img)

    # 1. Background radial mesh gradient
    center_x, center_y = size // 2, size // 2
    for r in range(size // 2 + 200, 0, -2):
        factor = r / (size // 2 + 200)
        # Deep violet-blue to dark obsidian
        red = int(12 + (30 - 12) * (1 - factor))
        green = int(14 + (20 - 14) * (1 - factor))
        blue = int(24 + (55 - 24) * (1 - factor))
        draw.ellipse(
            [center_x - r, center_y - r, center_x + r, center_y + r],
            fill=(red, green, blue)
        )

    # Glow layer
    glow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glow_draw = ImageDraw.Draw(glow)

    # Neon glow blobs
    glow_draw.ellipse([center_x - 320, center_y - 280, center_x + 320, center_y + 360], fill=(0, 242, 254, 45))
    glow_draw.ellipse([center_x - 260, center_y - 320, center_x + 280, center_y + 260], fill=(255, 0, 128, 40))
    glow_draw.ellipse([center_x - 180, center_y - 180, center_x + 220, center_y + 220], fill=(120, 0, 255, 60))
    glow = glow.filter(ImageFilter.GaussianBlur(70))

    img = Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB")
    draw = ImageDraw.Draw(img)

    # 2. Outer Neon Rounded Shield / Squircle
    shield_size = 680
    shield_x0 = (size - shield_size) // 2
    shield_y0 = (size - shield_size) // 2
    shield_x1 = shield_x0 + shield_size
    shield_y1 = shield_y0 + shield_size

    # Inner metallic glass container
    glass = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    glass_draw = ImageDraw.Draw(glass)
    glass_draw.rounded_rectangle(
        [shield_x0, shield_y0, shield_x1, shield_y1],
        radius=160,
        fill=(18, 22, 34, 220),
        outline=(0, 229, 255, 180),
        width=6
    )
    img = Image.alpha_composite(img.convert("RGBA"), glass).convert("RGB")
    draw = ImageDraw.Draw(img)

    # 3. Dynamic Audio Wavebars on the left and right
    wave_bars = [
        # (x, height, color)
        (-180, 110, (0, 242, 254)),
        (-140, 190, (0, 220, 255)),
        (-100, 290, (50, 180, 255)),
        (-60,  400, (130, 80, 255)),
    ]

    wave_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    w_draw = ImageDraw.Draw(wave_layer)

    bar_w = 22
    for rel_x, h, col in wave_bars:
        # Left side bars
        bx = center_x + rel_x - 80
        by0 = center_y - h // 2
        by1 = center_y + h // 2
        w_draw.rounded_rectangle([bx, by0, bx + bar_w, by1], radius=11, fill=col + (230,))

    # 4. Central Glowing Play & Storyteller Triangle
    # A vibrant gradient triangle pointing right (video play)
    poly_points = [
        (center_x - 30, center_y - 180),
        (center_x + 190, center_y),
        (center_x - 30, center_y + 180),
    ]

    # Draw neon shadow
    shadow_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    s_draw = ImageDraw.Draw(shadow_layer)
    s_draw.polygon(poly_points, fill=(0, 242, 254, 180))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(35))
    img = Image.alpha_composite(img.convert("RGBA"), shadow_layer).convert("RGB")

    # Draw gradient fill for play button
    play_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    p_draw = ImageDraw.Draw(play_layer)
    p_draw.polygon(poly_points, fill=(255, 255, 255, 250))
    
    # Accent slash (TikTok style cyan-pink split)
    slash_points = [
        (center_x - 30, center_y - 180),
        (center_x + 70, center_y - 80),
        (center_x + 10, center_y + 180),
        (center_x - 30, center_y + 180),
    ]
    p_draw.polygon(slash_points, fill=(0, 242, 254, 255))

    tip_points = [
        (center_x + 70, center_y - 80),
        (center_x + 190, center_y),
        (center_x + 10, center_y + 180),
    ]
    p_draw.polygon(tip_points, fill=(255, 0, 128, 255))

    img = Image.alpha_composite(img.convert("RGBA"), play_layer).convert("RGB")

    # 5. Little viral spark / star on top right
    spark_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    sp_draw = ImageDraw.Draw(spark_layer)
    sx, sy = center_x + 220, center_y - 180
    sp_draw.ellipse([sx - 24, sy - 24, sx + 24, sy + 24], fill=(255, 220, 0, 255))
    sp_draw.line([sx - 40, sy, sx + 40, sy], fill=(255, 255, 255, 255), width=6)
    sp_draw.line([sx, sy - 40, sx, sy + 40], fill=(255, 255, 255, 255), width=6)

    spark_layer = Image.alpha_composite(spark_layer, wave_layer)
    img = Image.alpha_composite(img.convert("RGBA"), spark_layer).convert("RGB")

    # Save exactly as 1024x1024 RGB PNG (No Alpha - Apple AppIcon requirement)
    img.save(output_path, "PNG")
    print(f"Generated AppIcon at: {output_path}")

if __name__ == "__main__":
    create_app_icon()
