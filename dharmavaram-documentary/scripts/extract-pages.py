import fitz
import os
import sys

PDF = "/root/.claude/uploads/8dbd53c7-1a39-5282-9a19-7f7e438367aa/3c311b31-2_years_of_good_governance_final.pdf"
OUT = os.path.join(os.path.dirname(__file__), "../public/pages")
os.makedirs(OUT, exist_ok=True)

doc = fitz.open(PDF)
print(f"Extracting {doc.page_count} pages at 2.5× scale...")

for i in range(doc.page_count):
    mat = fitz.Matrix(2.5, 2.5)
    pix = doc[i].get_pixmap(matrix=mat)
    path = os.path.join(OUT, f"page-{i+1:02d}.png")
    pix.save(path)
    print(f"  page-{i+1:02d}.png  {pix.width}×{pix.height}")

print("Done.")
