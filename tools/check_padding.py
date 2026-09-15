import bpy

for name in ['caesar_rear_run1.png', 'chibi_rear_run1.png', 'chibi_rear_run2.png', 'chibi_rear_jump.png', 'chibi_rear_slide.png']:
    path = f'assets/sprites/characters/{name}'
    img = bpy.data.images.load(path)
    w, h = img.size
    pixels = list(img.pixels) # RGBA flat list
    lowest_row = h
    highest_row = 0
    for y in range(h):
        for x in range(w):
            a = pixels[(y * w + x) * 4 + 3]
            if a > 0.1:
                if y < lowest_row:
                    lowest_row = y
                if y > highest_row:
                    highest_row = y
    print(f"{name}: size={w}x{h}, content bottom row={lowest_row}, top row={highest_row}, bottom_padding={lowest_row}")
