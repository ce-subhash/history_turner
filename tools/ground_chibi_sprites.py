import bpy

files = [
    ('chibi_rear_run1.png', 26),
    ('chibi_rear_run2.png', 26),
    ('chibi_rear_jump.png', 32),
    ('chibi_rear_slide.png', 22),
]

for filename, target_bottom in files:
    path = f"/Users/subhash/Games/assets/sprites/characters/{filename}"
    img = bpy.data.images.load(path)
    w, h = img.size
    pixels = list(img.pixels) # flat RGBA list
    
    # Find current lowest non-transparent row
    lowest_row = h
    highest_row = 0
    for y in range(h):
        for x in range(w):
            a = pixels[(y * w + x) * 4 + 3]
            if a > 0.05:
                if y < lowest_row:
                    lowest_row = y
                if y > highest_row:
                    highest_row = y
                    
    shift_down = lowest_row - target_bottom
    print(f"{filename}: lowest_row={lowest_row}, highest_row={highest_row}, shift_down={shift_down}")
    
    if shift_down > 0:
        new_pixels = [0.0] * (w * h * 4)
        for y in range(h):
            src_y = y + shift_down
            if 0 <= src_y < h:
                for x in range(w):
                    src_idx = (src_y * w + x) * 4
                    dst_idx = (y * w + x) * 4
                    new_pixels[dst_idx : dst_idx + 4] = pixels[src_idx : src_idx + 4]
        
        img.pixels = new_pixels
        img.filepath_raw = path
        img.file_format = 'PNG'
        img.save()
        print(f"Shifted {filename} down by {shift_down} pixels to ground the character firmly!")

print("All Chibi Leader sprites grounded successfully!")
