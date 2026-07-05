import fitz, os

PDF = "/root/.claude/uploads/8dbd53c7-1a39-5282-9a19-7f7e438367aa/3c311b31-2_years_of_good_governance_final.pdf"
doc = fitz.open(PDF)

OUT = "public/dept-images"
os.makedirs(OUT, exist_ok=True)

for page_num in range(2, 28):  # pages 3-28 (0-indexed: 2-27)
    page = doc[page_num]
    images = page.get_images(full=True)
    page_dir = "%s/page-%02d" % (OUT, page_num + 1)
    os.makedirs(page_dir, exist_ok=True)

    saved = []
    # Skip the first 2 images (repeated header/background graphics)
    dept_images = images[2:]

    for img in dept_images:
        xref = img[0]
        base_image = doc.extract_image(xref)
        w, h = base_image["width"], base_image["height"]
        # Skip icons/small decorative elements
        if w < 300 or h < 200:
            continue
        img_bytes = base_image["image"]
        ext = base_image["ext"]
        fname = "img-%02d.%s" % (len(saved) + 1, ext)
        fpath = "%s/%s" % (page_dir, fname)
        with open(fpath, "wb") as f:
            f.write(img_bytes)
        saved.append({"file": "dept-images/page-%02d/%s" % (page_num + 1, fname), "w": w, "h": h})

    dims = ["%dx%d" % (i["w"], i["h"]) for i in saved]
    print("page-%02d: %d dept images - %s" % (page_num + 1, len(saved), dims))
