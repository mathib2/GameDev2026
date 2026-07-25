#!/usr/bin/env python3
"""
Structural validator for the Rogue Protocol Godot project.

This is NOT a substitute for opening the project in Godot — it cannot check
GDScript semantics or whether a scene actually plays. What it does check is the
class of error that hand-editing .tscn/.tres files actually produces, and that
CI can catch without a Godot binary:

  1. every res:// path referenced by any file exists on disk
  2. every ExtResource("id") / SubResource("id") is declared in the same file
  3. every declared ext_resource / sub_resource is actually used
  4. every `script = ExtResource(...)` points at a .gd file that exists
  5. every node's `parent="..."` path resolves to a node declared earlier
  6. load_steps matches the number of declared resources + 1
  7. every autoload in project.godot points at a real script
  8. every @onready $NodePath in a script resolves in its paired scene
  9. data .tres files declare a non-empty, unique `id`

Usage:  python3 tools/validate_project.py [project_root]
Exit:   0 clean, 1 problems found
"""

import os
import re
import sys
from collections import defaultdict

ROOT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else
                       os.path.join(os.path.dirname(__file__), ".."))

errors = []
warnings = []


def err(f, msg):
    errors.append(f"{os.path.relpath(f, ROOT)}: {msg}")


def warn(f, msg):
    warnings.append(f"{os.path.relpath(f, ROOT)}: {msg}")


def res_to_abs(p):
    return os.path.join(ROOT, p[len("res://"):]) if p.startswith("res://") else None


def walk(exts):
    for base, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if d not in (".git", ".godot", ".import", "node_modules")]
        for fn in files:
            if fn.endswith(exts):
                yield os.path.join(base, fn)


# ── 1. every res:// path referenced anywhere exists ────────────────────────
RES_PATH = re.compile(r'res://[^"\'\)\s]+')

for f in walk((".tscn", ".tres", ".gd", ".godot")):
    try:
        text = open(f, encoding="utf-8").read()
    except UnicodeDecodeError:
        continue
    for m in set(RES_PATH.findall(text)):
        target = res_to_abs(m)
        if target and not os.path.exists(target):
            err(f, f"references missing file {m}")


# ── 2-6. scene / resource file internals ──────────────────────────────────
EXT_DECL = re.compile(r'^\[ext_resource ([^\]]*)\]', re.M)
SUB_DECL = re.compile(r'^\[sub_resource ([^\]]*)\]', re.M)
NODE_DECL = re.compile(r'^\[node ([^\]]*)\]', re.M)
ATTR = re.compile(r'(\w+)="([^"]*)"')
EXT_USE = re.compile(r'ExtResource\("([^"]+)"\)')
SUB_USE = re.compile(r'SubResource\("([^"]+)"\)')
HEADER = re.compile(r'^\[gd_(scene|resource)([^\]]*)\]', re.M)

seen_ids = defaultdict(list)

for f in walk((".tscn", ".tres")):
    text = open(f, encoding="utf-8").read()

    ext_ids, sub_ids = {}, set()
    for raw in EXT_DECL.findall(text):
        a = dict(ATTR.findall(raw))
        if "id" in a:
            ext_ids[a["id"]] = a
    for raw in SUB_DECL.findall(text):
        a = dict(ATTR.findall(raw))
        if "id" in a:
            sub_ids.add(a["id"])

    used_ext = set(EXT_USE.findall(text))
    used_sub = set(SUB_USE.findall(text))

    for u in used_ext - set(ext_ids):
        err(f, f'uses ExtResource("{u}") which is not declared')
    for u in used_sub - sub_ids:
        err(f, f'uses SubResource("{u}") which is not declared')
    for d in set(ext_ids) - used_ext:
        warn(f, f'declares ext_resource id "{d}" but never uses it')
    for d in sub_ids - used_sub:
        warn(f, f'declares sub_resource id "{d}" but never uses it')

    # script= must point at a .gd
    for sid in re.findall(r'script = ExtResource\("([^"]+)"\)', text):
        a = ext_ids.get(sid)
        if a and not a.get("path", "").endswith(".gd"):
            err(f, f'script = ExtResource("{sid}") does not point at a .gd file')

    # load_steps
    h = HEADER.search(text)
    if h:
        ha = dict(ATTR.findall(h.group(2)))
        m = re.search(r'load_steps=(\d+)', h.group(2))
        if m:
            declared = int(m.group(1))
            expected = len(ext_ids) + len(sub_ids) + 1
            if declared != expected:
                err(f, f"load_steps={declared} but file declares "
                       f"{len(ext_ids)} ext + {len(sub_ids)} sub (expected {expected})")

    # node parents
    if f.endswith(".tscn"):
        known = set()
        first = True
        for raw in NODE_DECL.findall(text):
            a = dict(ATTR.findall(raw))
            name, parent = a.get("name"), a.get("parent")
            if first and parent is None:
                known.add(".")
                first = False
            elif parent is None:
                err(f, f'node "{name}" has no parent= and is not the root')
            else:
                if parent not in known:
                    err(f, f'node "{name}" has parent="{parent}" which is not declared above it')
                known.add(name if parent == "." else f"{parent}/{name}")

    # .tres id uniqueness — only the [resource] block counts. Sub-resources
    # (rewards, dialogue lines) have their own `id` fields and must be ignored.
    if f.endswith(".tres") and "/data/" in f.replace("\\", "/"):
        body = text.split("\n[resource]\n")[-1] if "\n[resource]\n" in text else ""
        m = re.search(r'^id = &"([^"]*)"', body, re.M)
        if not m or not m.group(1):
            err(f, "data resource has no non-empty `id` in its [resource] block")
        else:
            seen_ids[m.group(1)].append(f)

for rid, files in seen_ids.items():
    if len(files) > 1:
        errors.append("duplicate data id '%s' in: %s" % (
            rid, ", ".join(os.path.relpath(x, ROOT) for x in files)))


# ── 7. autoloads ──────────────────────────────────────────────────────────
proj = os.path.join(ROOT, "project.godot")
autoloads = []
if os.path.exists(proj):
    text = open(proj, encoding="utf-8").read()
    block = re.search(r'\[autoload\](.*?)(\n\[|\Z)', text, re.S)
    if block:
        for name, path in re.findall(r'^(\w+)="\*?(res://[^"]+)"', block.group(1), re.M):
            autoloads.append(name)
            if not os.path.exists(res_to_abs(path)):
                err(proj, f"autoload {name} points at missing {path}")
    main = re.search(r'run/main_scene="(res://[^"]+)"', text)
    if main and not os.path.exists(res_to_abs(main.group(1))):
        err(proj, f"main_scene missing: {main.group(1)}")
else:
    errors.append("project.godot not found")


# ── 8. @onready $Node paths resolve in the paired scene ───────────────────
ONREADY = re.compile(r'@onready\s+var\s+\w+\s*:\s*[\w\.]+\s*=\s*\$([^\s#]+)')

script_to_scene = {}
for f in walk((".tscn",)):
    text = open(f, encoding="utf-8").read()
    ext_ids = {}
    for raw in EXT_DECL.findall(text):
        a = dict(ATTR.findall(raw))
        if "id" in a:
            ext_ids[a["id"]] = a
    root = NODE_DECL.search(text)
    if not root:
        continue
    ra = dict(ATTR.findall(root.group(1)))
    sid = re.search(r'script = ExtResource\("([^"]+)"\)', text)
    if sid and sid.group(1) in ext_ids:
        script_to_scene.setdefault(ext_ids[sid.group(1)]["path"], []).append(f)

for script_res, scenes in script_to_scene.items():
    sp = res_to_abs(script_res)
    if not sp or not os.path.exists(sp):
        continue
    body = open(sp, encoding="utf-8").read()
    wanted = [w.strip('"') for w in ONREADY.findall(body)]
    if not wanted:
        continue
    for scene in scenes:
        text = open(scene, encoding="utf-8").read()
        nodes = set()
        first = True
        for raw in NODE_DECL.findall(text):
            a = dict(ATTR.findall(raw))
            name, parent = a.get("name"), a.get("parent")
            if first and parent is None:
                first = False
                continue
            nodes.add(name if parent == "." else f"{parent}/{name}")
        for w in wanted:
            if w not in nodes:
                err(scene, f'{os.path.basename(sp)} does @onready $ {w} '
                           f'but that node does not exist in this scene')


# ── 10. content cross-references resolve ──────────────────────────────────
# Data refers to other data by StringName id. A typo there fails silently at
# runtime (an item never granted, a mission never started), so check it here.
known_ids = set(seen_ids)

REF_FIELDS = {
    "grants_item": "item",
    "required_item": "item",
    "starts_mission": "mission",
}

for f in walk((".tres",)):
    if "/data/" not in f.replace("\\", "/"):
        continue
    text = open(f, encoding="utf-8").read()
    for field, kind in REF_FIELDS.items():
        for val in re.findall(r'^%s = &"([^"]*)"' % field, text, re.M):
            if val and val not in known_ids:
                err(f, f'{field} = &"{val}" does not match any data resource id')
    # RewardData sub-resources: kind 0 = ITEM, kind 4 = UNLOCK_MISSION
    for block in re.split(r'^\[sub_resource ', text, flags=re.M)[1:]:
        km = re.search(r'^kind = (\d+)', block, re.M)
        im = re.search(r'^id = &"([^"]*)"', block, re.M)
        if not km or not im or not im.group(1):
            continue
        if km.group(1) in ("0", "4") and im.group(1) not in known_ids:
            err(f, f'reward references id &"{im.group(1)}" '
                   f'which does not match any data resource')

# every flag a mission waits on should be set by something, or it can never
# complete. Warn rather than fail: a flag may legitimately be set from code.
flag_setters = set()
for f in walk((".tres", ".tscn", ".gd")):
    text = open(f, encoding="utf-8").read()
    if f.endswith(".gd"):
        for m in re.findall(r'set_flag\(&"([^"]+)"\)', text):
            flag_setters.add(m)
    for field in ("success_flags", "failure_flags", "sets_flags",
                  "completion_flags", "discovery_flag"):
        for m in re.findall(r'^%s = (?:Array\[StringName\]\()?\[?([^\]\n]*)' % field,
                            text, re.M):
            flag_setters.update(re.findall(r'&"([^"]+)"', m))

for f in walk((".tres",)):
    if "/missions/" not in f.replace("\\", "/"):
        continue
    text = open(f, encoding="utf-8").read()
    for flag in re.findall(r'^completed_when_flag = &"([^"]+)"', text, re.M):
        if flag not in flag_setters:
            warn(f, f'objective waits on flag &"{flag}" that nothing appears '
                    f'to set — the mission may never complete')


# ── report ────────────────────────────────────────────────────────────────
print(f"Rogue Protocol — project validation")
print(f"  root: {ROOT}")
print(f"  autoloads: {len(autoloads)}  ({', '.join(autoloads)})")
print(f"  scenes: {len(list(walk(('.tscn',))))}   resources: {len(list(walk(('.tres',))))}"
      f"   scripts: {len(list(walk(('.gd',))))}")
print()

def dedupe(seq):
    seen, out = set(), []
    for x in seq:
        if x not in seen:
            seen.add(x)
            out.append(x)
    return out

errors = dedupe(errors)
warnings = dedupe(warnings)

for w in warnings:
    print(f"  WARN  {w}")
if warnings:
    print()
for e in errors:
    print(f"  FAIL  {e}")

print()
if errors:
    print(f"{len(errors)} error(s), {len(warnings)} warning(s)")
    sys.exit(1)
print(f"No structural errors. {len(warnings)} warning(s).")
print("NOTE: this does not verify GDScript semantics or runtime behaviour.")
sys.exit(0)
