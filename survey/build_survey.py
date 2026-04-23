#!/usr/bin/env python3
"""
Build the AI Detection Qualtrics survey via the REST API.

Creates a new survey with 80 image blocks (40 AI + 40 real photos), 2 attention
checks, and a 3-pool stratified randomizer that shows each respondent 10 images.
Clones demographic, AI usage, and intro blocks from an existing template survey.

Requires QUALTRICS_API_TOKEN environment variable.
Requires data/graphic_ids.json (run scripts/upload_images.py first).

Usage:
  export QUALTRICS_API_TOKEN=...
  python3 build_survey.py
"""

import os
import json
import random
import sys
import time
from pathlib import Path

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

random.seed(int(time.time()))

API_TOKEN = os.environ["QUALTRICS_API_TOKEN"]
BASE_URL = "https://bowdoincollege.qualtrics.com/API/v3"
TEMPLATE_SURVEY_ID = os.environ.get("TEMPLATE_SURVEY_ID", "SV_85QraWOZXmG49ee")
GRAPHIC_CACHE = Path(__file__).resolve().parent.parent / "data" / "graphic_ids.json"
SECTION_COUNTS = [3, 3, 4]  # images per randomizer section, sum = 10

HEADERS = {"X-API-TOKEN": API_TOKEN}
JSON_HEADERS = {"X-API-TOKEN": API_TOKEN, "Content-Type": "application/json"}

#  API HELPERS
def api(method, path, **kwargs):
    """Make an API call, exit on failure. Returns the 'result' dict."""
    url = BASE_URL + path
    r = requests.request(method, url, timeout=120, **kwargs)
    try:
        body = r.json()
    except Exception:
        body = {}
    if r.status_code not in (200, 201):
        print(f"\n {method} {path} -> {r.status_code}")
        # Print full error body, not just result
        print(json.dumps(body, indent=2)[:800] if body else r.text[:800])
        sys.exit(1)
    return body.get("result", {})

def graphic_url(gid):
    return f"https://bowdoincollege.qualtrics.com/CP/Graphic.php?IM={gid}"

#  LOAD GRAPHIC IDS
def load_graphic_ids():
    if not GRAPHIC_CACHE.exists():
        sys.exit(f" {GRAPHIC_CACHE} not found. Run build_survey.py first.")
    print(" Loading graphic IDs from cache...")
    with open(GRAPHIC_CACHE) as f:
        d = json.load(f)
    fake, real, attn = d.get("fake", []), d.get("real", []), d.get("attn", [])
    print(f"   Fake: {len(fake)}, Real: {len(real)}, Attn: {len(attn)}")
    return fake, real, attn

#  READ ORIGINAL SURVEY
def read_original_survey():
    """Read the existing survey to clone its questions."""
    print(f"\n Reading original survey {ORIGINAL_SID}...")
    survey = api("GET", f"/survey-definitions/{ORIGINAL_SID}", headers=JSON_HEADERS)
    blocks = survey.get("Blocks", {})
    questions = survey.get("Questions", {})

    # Map QIDs to block descriptions
    block_questions = {}  # block_desc -> [(order, qid, question_payload)]
    for bid, blk in blocks.items():
        desc = blk.get("Description", "")
        qlist = []
        for i, be in enumerate(blk.get("BlockElements", [])):
            if be.get("Type") == "Question":
                qid = be["QuestionID"]
                if qid in questions:
                    qlist.append((i, qid, questions[qid]))
            # Skip page breaks and other non-question elements
        if qlist:
            block_questions[desc] = qlist

    for desc, qs in block_questions.items():
        print(f"   {desc}: {len(qs)} questions")

    return block_questions

def clone_question_payload(q):
    """Extract the fields needed to recreate a question via the API.
    Returns None for question types that shouldn't be cloned."""
    qtype = q.get("QuestionType", "")

    # Skip Meta questions (browser metadata)  -  Qualtrics auto-captures these
    # and they require special handling that doesn't clone well
    if qtype == "Meta":
        return None

    payload = {}
    COPY_FIELDS = [
        "QuestionText", "QuestionType", "Selector", "SubSelector",
        "Configuration", "Choices", "ChoiceOrder",
        "Validation", "DataVisibility", "DefaultChoices",
        "Labels", "DataExportTag",
    ]
    for field in COPY_FIELDS:
        if field in q:
            val = q[field]
            # Fix: Labels must be dict, never list
            if field == "Labels" and isinstance(val, list):
                val = {}
            if val is not None:
                payload[field] = val

    # Ensure DataExportTag exists (required for some question types)
    if "DataExportTag" not in payload:
        payload["DataExportTag"] = ""

    return payload

#  SURVEY CREATION
def create_blank_survey(name="AI Detection v2"):
    print(f"\n Creating blank survey: '{name}'...")
    result = api("POST", "/survey-definitions", headers=JSON_HEADERS,
                 json={"SurveyName": name, "Language": "EN", "ProjectCategory": "CORE"})
    sid = result.get("SurveyID", "")
    if not sid:
        sys.exit(" Could not create survey.")
    print(f"    Created: {sid}")
    return sid

def get_default_block(sid):
    survey = api("GET", f"/survey-definitions/{sid}", headers=JSON_HEADERS)
    for bid, blk in survey.get("Blocks", {}).items():
        if blk.get("Type") == "Default":
            return bid
    return None

def create_block(sid, description):
    result = api("POST", f"/survey-definitions/{sid}/blocks",
                 headers=JSON_HEADERS,
                 json={"Type": "Standard", "Description": description})
    return result.get("BlockID", "")

_q_counter = [0]
def add_question(sid, block_id, payload):
    # Ensure DataExportTag is always present (Qualtrics requires it)
    if "DataExportTag" not in payload or not payload["DataExportTag"]:
        _q_counter[0] += 1
        payload["DataExportTag"] = f"Q{_q_counter[0]}"
    result = api("POST", f"/survey-definitions/{sid}/questions",
                 headers=JSON_HEADERS,
                 params={"blockId": block_id},
                 json=payload)
    return result.get("QuestionID", "")

def update_flow(sid, flow_payload):
    api("PUT", f"/survey-definitions/{sid}/flow",
        headers=JSON_HEADERS, json=flow_payload)

#  IMAGE QUESTION PAYLOADS
def image_display_payload(gid, with_counter=True):
    img = (f'<div style="text-align:center;">'
           f'<img src="{graphic_url(gid)}" '
           f'style="max-width:100%;max-height:580px;height:auto;border-radius:4px;"/>'
           f'</div>')
    if with_counter:
        top = '<p id="img-counter" style="text-align:center;color:#666;font-size:13px;margin-bottom:6px;">Loading\u2026</p>'
    else:
        top = '<p style="text-align:center;color:#888;font-size:13px;margin-bottom:6px;">Attention Check</p>'
    return {
        "QuestionText": top + img,
        "QuestionType": "DB",
        "Selector": "TB",
        "Configuration": {"QuestionDescriptionOption": "UseText"},
        "Validation": {"Settings": {"Type": "None"}},
    }

def real_or_ai_payload():
    return {
        "QuestionText": "Is this image a real photograph or AI-generated?",
        "QuestionType": "MC",
        "Selector": "SAVR",
        "SubSelector": "TX",
        "Configuration": {"QuestionDescriptionOption": "UseText"},
        "Choices": {"1": {"Display": "Real photograph"},
                    "2": {"Display": "AI-generated image"}},
        "ChoiceOrder": [1, 2],
        "Validation": {"Settings": {"ForceResponse": "ON",
                                     "ForceResponseType": "ON",
                                     "Type": "None"}},
    }

def confidence_slider_payload():
    return {
        "QuestionText": "How confident are you in your answer?",
        "QuestionType": "Slider",
        "Selector": "HSLIDER",
        "Configuration": {
            "QuestionDescriptionOption": "UseText",
            "CSSliderMin": 0, "CSSliderMax": 10, "GridLines": 10,
            "NumDecimals": "0", "ShowValue": True, "CustomStart": True,
            "NotApplicable": False, "MobileFirst": True,
            "SliderStartPositions": {"1": 5}, "SnapToGrid": False,
        },
        "Choices": {"1": {"Display": "Confidence"}},
        "ChoiceOrder": [1],
        "Validation": {"Settings": {"ForceResponse": "OFF",
                                     "ForceResponseType": "ON",
                                     "Type": "None"}},
    }

def attention_mc_payload():
    return {
        "QuestionText": (
            "Is this image a real photograph or AI-generated?"
            "<br><em style='font-size:12px;color:#888;'>"
            "Please answer carefully \u2014 this is a quality check.</em>"
        ),
        "QuestionType": "MC",
        "Selector": "SAVR",
        "SubSelector": "TX",
        "Configuration": {"QuestionDescriptionOption": "UseText"},
        "Choices": {"1": {"Display": "Real photograph"},
                    "2": {"Display": "AI-generated image"}},
        "ChoiceOrder": [1, 2],
        "Validation": {"Settings": {"ForceResponse": "ON",
                                     "ForceResponseType": "ON",
                                     "Type": "None"}},
    }

def instructions_payload():
    return {
        "QuestionText": (
            "You are about to view a series of 10 images. Each may be a real photograph "
            "or AI-generated. After viewing each image, indicate your assessment and "
            "your confidence level.<br><br>"
            "<strong>Please take your time.</strong> These images were selected because "
            "they are challenging to classify \u2014 look carefully before responding. "
            "You will advance automatically after each answer."
        ),
        "QuestionType": "DB",
        "Selector": "TB",
        "Configuration": {"QuestionDescriptionOption": "UseText"},
        "Validation": {"Settings": {"Type": "None"}},
    }

#  FLOW HELPERS
_flow_counter = [0]
def flow_id():
    _flow_counter[0] += 1
    return f"FL_{_flow_counter[0]:04d}"

def block_flow_ref(bid, ref_type="Standard"):
    return {"Type": ref_type, "ID": bid, "FlowID": flow_id(), "Autofill": []}

def block_randomizer(bids, subset):
    return {
        "Type": "BlockRandomizer",
        "FlowID": flow_id(),
        "SubSet": subset,
        "EvenPresentation": True,
        "Flow": [block_flow_ref(bid) for bid in bids],
    }

def embedded_data_node(fields):
    return {
        "Type": "EmbeddedData",
        "FlowID": flow_id(),
        "EmbeddedData": [
            {"Description": k, "Type": "Custom", "Field": k,
             "VariableType": "String", "DataVisibility": [],
             "AnalyzeText": False, "Value": str(v)}
            for k, v in fields.items()
        ],
    }

#  MAIN
def main():
    start_time = time.time()

    #  Load images
    fake_imgs, real_imgs, attn_imgs = load_graphic_ids()
    if not fake_imgs or not real_imgs:
        sys.exit(" No Fake or Real images. Check graphic_ids.json.")
    if len(attn_imgs) < 2:
        sys.exit(f" Need >=2 attention images, found {len(attn_imgs)}")

    #  Read original survey questions
    orig_blocks = read_original_survey()

    #  Create blank survey
    sid = create_blank_survey("AI Detection v2")

    #  Get the default block ID
    default_bid = get_default_block(sid)
    print(f"   Default block: {default_bid}")

    #
    # REBUILD FOUNDATIONAL BLOCKS (clone from original)
    #

    # --- Intro block (use default block) ---
    intro_id = default_bid
    print(f"\n Populating Intro block ({intro_id})...")

    # Update the intro consent text (QID37 in original is a DB display)
    intro_consent = {
        "QuestionText": (
            "This study examines how people distinguish between AI-generated and real images. "
            "The survey takes approximately 10\u201315 minutes to complete. You will be shown "
            "<strong>10 images</strong> and asked whether each is a real photograph or AI-generated."
            "<br><br><strong>Please take your time with each image.</strong> "
            "We specifically selected images that are difficult to classify \u2014 "
            "careful observation will serve you well. Responses are anonymous and used solely "
            "for academic research. Thank you for participating."
        ),
        "QuestionType": "DB",
        "Selector": "TB",
        "Configuration": {"QuestionDescriptionOption": "UseText"},
        "Validation": {"Settings": {"Type": "None"}},
    }
    add_question(sid, intro_id, intro_consent)

    # Clone intro questions from original (QID4 = leaderboard opt-in, QID36 = meta)
    if "Intro" in orig_blocks:
        for _, qid, q in orig_blocks["Intro"]:
            # Skip the original study description (QID37)  -  we replaced it above
            if q.get("QuestionType") == "DB":
                continue
            payload = clone_question_payload(q)
            if payload is None:
                print(f"   Skipped {qid} [{q.get('QuestionType')}] (not clonable)")
                continue
            if payload.get("QuestionText"):
                new_qid = add_question(sid, intro_id, payload)
                print(f"   Cloned {qid} -> {new_qid} [{q.get('QuestionType')}]")

    # --- Demographics block ---
    print(f"\n Creating Demographics block...")
    demo_id = create_block(sid, "Demographics")
    if "Demographics" in orig_blocks:
        for _, qid, q in orig_blocks["Demographics"]:
            payload = clone_question_payload(q)
            if payload is None:
                print(f"   Skipped {qid} [{q.get('QuestionType')}] (not clonable)")
                continue
            if payload.get("QuestionText"):
                new_qid = add_question(sid, demo_id, payload)
                print(f"   Cloned {qid} -> {new_qid}")
    print(f"   Demographics block: {demo_id}")

    # --- AI Usage Questions block ---
    print(f"\n Creating AI Usage Questions block...")
    ai_usage_id = create_block(sid, "AI Usage Questions")
    if "AI Usage Questions" in orig_blocks:
        for _, qid, q in orig_blocks["AI Usage Questions"]:
            payload = clone_question_payload(q)
            if payload is None:
                print(f"   Skipped {qid} [{q.get('QuestionType')}] (not clonable)")
                continue
            if payload.get("QuestionText"):
                new_qid = add_question(sid, ai_usage_id, payload)
                print(f"   Cloned {qid} -> {new_qid}")
    print(f"   AI Usage block: {ai_usage_id}")

    # --- Image Instructions block ---
    print(f"\n Creating Image Instructions block...")
    inst_block_id = create_block(sid, "Image Instructions")
    add_question(sid, inst_block_id, instructions_payload())
    print(f"   Image Instructions block: {inst_block_id}")

    #
    # BUILD IMAGE BLOCKS
    #

    # Shuffle and split into 3 pools
    random.shuffle(fake_imgs)
    random.shuffle(real_imgs)
    random.shuffle(attn_imgs)
    paired = list(zip(fake_imgs, real_imgs))
    random.shuffle(paired)
    all_images = []
    for f, r in paired:
        all_images.extend([("F", f), ("R", r)])
    all_images += [("F", img) for img in fake_imgs[len(real_imgs):]]
    all_images += [("R", img) for img in real_imgs[len(fake_imgs):]]
    random.shuffle(all_images)

    n = len(all_images)
    pool_a = all_images[:n // 3]
    pool_b = all_images[n // 3:2 * n // 3]
    pool_c = all_images[2 * n // 3:]
    attn_pair = attn_imgs[:2]

    print(f"\n  Pool A: {len(pool_a)} images (show {SECTION_COUNTS[0]})")
    print(f"   Pool B: {len(pool_b)} images (show {SECTION_COUNTS[1]})")
    print(f"   Pool C: {len(pool_c)} images (show {SECTION_COUNTS[2]})")

    # Create image blocks (4 API calls each: 1 block + 3 questions)
    print(f"\n Creating image blocks... (4 API calls each, ~3-5 minutes total)")
    pool_a_ids, pool_b_ids, pool_c_ids = [], [], []
    total = len(pool_a) + len(pool_b) + len(pool_c)
    count = 0
    img_start = time.time()

    for pool, pool_ids, label in [(pool_a, pool_a_ids, "A"),
                                   (pool_b, pool_b_ids, "B"),
                                   (pool_c, pool_c_ids, "C")]:
        for i, (ftype, img) in enumerate(pool):
            count += 1
            desc = f"Img_{ftype}_{label}{i + 1:03d}"
            bid = create_block(sid, desc)
            pool_ids.append(bid)

            add_question(sid, bid, image_display_payload(img["id"], with_counter=True))
            add_question(sid, bid, real_or_ai_payload())
            add_question(sid, bid, confidence_slider_payload())

            if count % 10 == 0 or count == total:
                elapsed = time.time() - img_start
                rate = count / elapsed if elapsed > 0 else 0
                eta = (total - count) / rate if rate > 0 else 0
                print(f"   [{count}/{total}] blocks ({elapsed:.0f}s elapsed, ~{eta:.0f}s remaining)")

    # Attention check blocks
    print(f"\n Creating attention check blocks...")
    attn1_bid = create_block(sid, "AttentionCheck_1")
    add_question(sid, attn1_bid, image_display_payload(attn_pair[0]["id"], with_counter=False))
    add_question(sid, attn1_bid, attention_mc_payload())

    attn2_bid = create_block(sid, "AttentionCheck_2")
    attn2_gid = attn_pair[1]["id"] if len(attn_pair) > 1 else attn_pair[0]["id"]
    add_question(sid, attn2_bid, image_display_payload(attn2_gid, with_counter=False))
    add_question(sid, attn2_bid, attention_mc_payload())
    print(f"    2 attention check blocks")

    #
    # SET SURVEY FLOW
    #

    print(f"\n Setting survey flow...")
    flow_nodes = [
        embedded_data_node({"imgCount": "0"}),
        block_flow_ref(intro_id, "Block"),     # Default block uses "Block" type
        block_flow_ref(inst_block_id),
        block_randomizer(pool_a_ids, SECTION_COUNTS[0]),
        block_flow_ref(attn1_bid),
        block_randomizer(pool_b_ids, SECTION_COUNTS[1]),
        block_flow_ref(attn2_bid),
        block_randomizer(pool_c_ids, SECTION_COUNTS[2]),
        block_flow_ref(demo_id),
        block_flow_ref(ai_usage_id),
    ]

    flow_payload = {
        "Type": "Root",
        "FlowID": "FL_1",
        "Flow": flow_nodes,
        "Properties": {"Count": len(flow_nodes)},
    }

    update_flow(sid, flow_payload)
    print(f"    Survey flow set")

    #
    # DONE
    #

    elapsed = time.time() - start_time
    url = f"https://bowdoincollege.qualtrics.com/survey-builder/{sid}/edit"
    print(f"\n{'=' * 60}")
    print(f"    SURVEY CREATED SUCCESSFULLY  ({elapsed:.0f}s)")
    print(f"{'=' * 60}")
    print(f"   Survey ID:       {sid}")
    print(f"   Image blocks:    {count}")
    print(f"   Attention checks: 2")
    print(f"   Each respondent sees: 10 random images + 2 attention checks")
    print(f"\n->  Open in Qualtrics:")
    print(f"   {url}")

if __name__ == "__main__":
    main()
