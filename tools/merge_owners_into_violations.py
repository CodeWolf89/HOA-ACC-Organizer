#!/usr/bin/env python3
# Copyright © 2026 Christopher Mcmahon-Sutton.
# Licensed under the PolyForm Perimeter License 1.0.1.
# Author: Christopher Mcmahon-Sutton.
# Additional modification, documentation, and testing assistance: ChatGPT (GPT-5.6 Sol), OpenAI — 2026-09-13.
# See LICENSE, NOTICE.md, and RESOURCE-RIGHTS.md in the repository root.

"""
Merge owner names from an .xlsx homeowner workbook into an ACC violation JSON export.

No third-party Python packages required.
It reads the XLSX OpenXML structure directly and matches primarily by lot number.

Usage:
  python3 merge_owners_into_violations.py homeowners.xlsx violations.json output.json
"""
import sys, json, zipfile, re, xml.etree.ElementTree as ET
from pathlib import Path

NS = {"m":"http://schemas.openxmlformats.org/spreadsheetml/2006/main",
      "r":"http://schemas.openxmlformats.org/officeDocument/2006/relationships"}
RELNS = {"p":"http://schemas.openxmlformats.org/package/2006/relationships"}

def col_index(cell_ref):
    letters = re.match(r"[A-Z]+", cell_ref).group(0)
    n = 0
    for c in letters: n = n*26 + ord(c)-64
    return n-1

def xlsx_rows(path):
    with zipfile.ZipFile(path) as z:
        shared = []
        if "xl/sharedStrings.xml" in z.namelist():
            root = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in root.findall("m:si", NS):
                shared.append("".join(t.text or "" for t in si.iter("{%s}t" % NS["m"])))

        wb = ET.fromstring(z.read("xl/workbook.xml"))
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        relmap = {r.attrib["Id"]: r.attrib["Target"] for r in rels.findall("p:Relationship", RELNS)}
        sheets = wb.find("m:sheets", NS)
        if sheets is None: return
        for s in sheets:
            rid = s.attrib["{%s}id" % NS["r"]]
            target = relmap[rid].lstrip("/")
            if not target.startswith("xl/"): target = "xl/" + target
            root = ET.fromstring(z.read(target))
            for row in root.findall(".//m:sheetData/m:row", NS):
                vals = {}
                for c in row.findall("m:c", NS):
                    idx = col_index(c.attrib["r"])
                    typ = c.attrib.get("t")
                    v = c.find("m:v", NS)
                    inline = c.find("m:is", NS)
                    if typ == "s" and v is not None:
                        value = shared[int(v.text)]
                    elif typ == "inlineStr" and inline is not None:
                        value = "".join(t.text or "" for t in inline.iter("{%s}t" % NS["m"]))
                    else:
                        value = v.text if v is not None and v.text is not None else ""
                    vals[idx] = value
                if vals:
                    width = max(vals)+1
                    yield [vals.get(i, "") for i in range(width)]

def norm(s):
    return re.sub(r"[^a-z0-9]+", " ", str(s).lower()).strip()

def find_header(rows):
    aliases = {
        "lot": {"lot","lot number","lot no","lot num","lot #"},
        "owner": {"owner","owner name","homeowner","homeowner name","property owner"},
        "address": {"address","property address","primary address","street address"}
    }
    for r_i, row in enumerate(rows[:40]):
        n = [norm(x).replace(" #","") for x in row]
        lot = next((i for i,x in enumerate(n) if x in aliases["lot"] or x=="lot number"), None)
        owner = next((i for i,x in enumerate(n) if x in aliases["owner"]), None)
        addr = next((i for i,x in enumerate(n) if x in aliases["address"]), None)
        if lot is not None and owner is not None:
            return r_i, lot, owner, addr
    raise SystemExit("Could not locate lot and owner columns in workbook.")

def clean_lot(v):
    s = str(v).strip()
    if re.fullmatch(r"\d+\.0", s): s = s[:-2]
    return s

def main():
    if len(sys.argv) != 4:
        raise SystemExit(__doc__)
    xlsx, src_json, out_json = map(Path, sys.argv[1:])
    rows = list(xlsx_rows(xlsx))
    h, lot_i, owner_i, addr_i = find_header(rows)
    owners = {}
    duplicates = []
    for row in rows[h+1:]:
        if max(lot_i, owner_i) >= len(row): continue
        lot = clean_lot(row[lot_i])
        owner = str(row[owner_i]).strip()
        if not lot or not owner: continue
        address = str(row[addr_i]).strip() if addr_i is not None and addr_i < len(row) else ""
        if lot in owners and owners[lot]["ownerName"] != owner: duplicates.append(lot)
        owners[lot] = {"ownerName": owner, "address": address}

    data = json.loads(src_json.read_text(encoding="utf-8"))
    matched, missing, address_mismatch = 0, set(), []
    for report in data.get("reports", []):
        prop = report.get("property") or {}
        lot = clean_lot(prop.get("lotNumber", ""))
        rec = owners.get(lot)
        if not rec:
            if lot: missing.add(lot)
            continue
        prop["ownerName"] = rec["ownerName"]
        report["property"] = prop
        matched += 1
        a, b = norm(prop.get("primaryAddress","")), norm(rec["address"])
        if a and b and a != b and a not in b and b not in a:
            address_mismatch.append((lot, prop.get("primaryAddress",""), rec["address"]))

    out_json.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"Reports matched: {matched}")
    print(f"Violation lots missing from workbook: {len(missing)}")
    if missing: print("  " + ", ".join(sorted(missing, key=lambda x:(not x.isdigit(), int(x) if x.isdigit() else x))))
    print(f"Duplicate owner lot rows: {len(set(duplicates))}")
    print(f"Address mismatches to review: {len(address_mismatch)}")
    for row in address_mismatch[:30]:
        print("  lot %s | JSON: %s | XLSX: %s" % row)

if __name__ == "__main__":
    main()
