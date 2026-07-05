import anthropic, base64, json, os, sys

client = anthropic.Anthropic()
PAGES_DIR = "public/pages"
OUT_FILE = "src/data/deptContent.json"

# Pages 3-28 are department pages (index 2-27)
DEPT_PAGES = list(range(3, 29))  # pages 3 to 28

results = {}

for page_num in DEPT_PAGES:
    png_path = f"{PAGES_DIR}/page-{page_num:02d}.png"
    if not os.path.exists(png_path):
        print(f"Missing: {png_path}", file=sys.stderr)
        continue

    with open(png_path, "rb") as f:
        img_b64 = base64.b64encode(f.read()).decode()

    print(f"Processing page {page_num}...", file=sys.stderr)

    response = client.messages.create(
        model="claude-sonnet-4-6",
        max_tokens=1024,
        messages=[{
            "role": "user",
            "content": [
                {
                    "type": "image",
                    "source": {"type": "base64", "media_type": "image/png", "data": img_b64}
                },
                {
                    "type": "text",
                    "text": """This is a page from an Indian government report about 2 years of governance achievements in Dharmavaram constituency, Andhra Pradesh.

Extract and return a JSON object with these fields:
{
  "dept_name_telugu": "department name in Telugu script",
  "dept_name_english": "department name in English",
  "highlights": [
    "key achievement or stat 1 (keep Telugu text if present, include numbers)",
    "key achievement or stat 2",
    "key achievement or stat 3",
    "key achievement or stat 4",
    "key achievement or stat 5"
  ]
}

Return ONLY valid JSON, no explanation. Extract up to 5 most important highlights with specific numbers/rupee amounts where visible. Keep Telugu text as-is."""
                }
            ]
        }]
    )

    text = response.content[0].text.strip()
    # Remove markdown code fences if present
    if text.startswith("```"):
        text = text.split("```")[1]
        if text.startswith("json"):
            text = text[4:]
    text = text.strip()

    try:
        data = json.loads(text)
        results[f"page-{page_num:02d}"] = data
        print(f"  -> {data.get('dept_name_english', '?')}", file=sys.stderr)
    except json.JSONDecodeError as e:
        print(f"  JSON error page {page_num}: {e}\n  Raw: {text[:200]}", file=sys.stderr)
        results[f"page-{page_num:02d}"] = {"dept_name_telugu": "", "dept_name_english": f"Page {page_num}", "highlights": []}

with open(OUT_FILE, "w", encoding="utf-8") as f:
    json.dump(results, f, ensure_ascii=False, indent=2)

print(f"\nSaved to {OUT_FILE}", file=sys.stderr)
