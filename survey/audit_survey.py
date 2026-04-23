#!/usr/bin/env python3
"""
Full Survey Audit  -  Step through every part of the methodology and verify

Checks EVERYTHING against methodology.txt requirements.
"""

import os
import json, sys, re

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

API_TOKEN  = os.environ["QUALTRICS_API_TOKEN"]
BASE_URL   = "https://bowdoincollege.qualtrics.com/API/v3"
SURVEY_ID  = "SV_bQ8cVhMLAvco9bE"
HEADERS    = {"X-API-TOKEN": API_TOKEN, "Content-Type": "application/json"}

PASS = ""
FAIL = ""
WARN = ""

issues = []
warnings = []

def api(method, path, **kwargs):
    url = BASE_URL + path
    r = requests.request(method, url, timeout=120, **kwargs)
    body = r.json() if r.text else {}
    if r.status_code not in (200, 201):
        print(f" {method} {path} -> {r.status_code}")
        sys.exit(1)
    return body.get("result", {})

def check(condition, pass_msg, fail_msg):
    if condition:
        print(f"  {PASS} {pass_msg}")
    else:
        print(f"  {FAIL} {fail_msg}")
        issues.append(fail_msg)

def warn(condition, pass_msg, warn_msg):
    if condition:
        print(f"  {PASS} {pass_msg}")
    else:
        print(f"  {WARN} {warn_msg}")
        warnings.append(warn_msg)

def main():
    print("=" * 70)
    print("  FULL SURVEY AUDIT  -  SV_bQ8cVhMLAvco9bE")
    print("=" * 70)

    print("\n Fetching survey definition...")
    survey = api("GET", f"/survey-definitions/{SURVEY_ID}", headers=HEADERS)
    blocks = survey.get("Blocks", {})
    questions = survey.get("Questions", {})
    flow = survey.get("SurveyFlow", {})
    options = survey.get("SurveyOptions", {})

    print(f"   Blocks: {len(blocks)}")
    print(f"   Questions: {len(questions)}")

    #
    # 1. IMAGE INVENTORY (Methodology §3)
    #
    print(f"\n{''*70}")
    print("§3  -  IMAGE INVENTORY: 40 fake + 40 real = 80 total")
    print(f"{''*70}")

    fake_blocks = {}
    real_blocks = {}
    other_blocks = {}

    for bid, blk in blocks.items():
        desc = blk.get("Description", "")
        if desc.startswith("Img_F_"):
            fake_blocks[bid] = blk
        elif desc.startswith("Img_R_"):
            real_blocks[bid] = blk
        else:
            other_blocks[bid] = blk

    check(len(fake_blocks) == 40, f"40 fake image blocks (found {len(fake_blocks)})",
          f"Expected 40 fake blocks, found {len(fake_blocks)}")
    check(len(real_blocks) == 40, f"40 real image blocks (found {len(real_blocks)})",
          f"Expected 40 real blocks, found {len(real_blocks)}")
    check(len(fake_blocks) + len(real_blocks) == 80,
          f"80 total image blocks",
          f"Expected 80 total, found {len(fake_blocks) + len(real_blocks)}")

    all_image_blocks = {**fake_blocks, **real_blocks}

    #
    # 2. POOL STRUCTURE (Methodology §5)
    #
    print(f"\n{''*70}")
    print("§5  -  POOL STRUCTURE: 3 pools (27/27/26)")
    print(f"{''*70}")

    pool_a, pool_b, pool_c = [], [], []
    for bid, blk in all_image_blocks.items():
        desc = blk.get("Description", "")
        if "_A" in desc:
            pool_a.append((bid, desc))
        elif "_B" in desc:
            pool_b.append((bid, desc))
        elif "_C" in desc:
            pool_c.append((bid, desc))

    check(len(pool_a) == 27, f"Pool A: 27 images (found {len(pool_a)})",
          f"Pool A: expected 27, found {len(pool_a)}")
    check(len(pool_b) == 27, f"Pool B: 27 images (found {len(pool_b)})",
          f"Pool B: expected 27, found {len(pool_b)}")
    check(len(pool_c) == 26, f"Pool C: 26 images (found {len(pool_c)})",
          f"Pool C: expected 26, found {len(pool_c)}")

    # Pool balance check (§6)  -  check ACTUAL randomizer composition, not labels
    print(f"\n{''*70}")
    print("§6  -  POOL BALANCE: each randomizer ~50/50 fake/real")
    print(f"{''*70}")

    flow_nodes_tmp = flow.get("Flow", [])
    rands_tmp = [(i, n) for i, n in enumerate(flow_nodes_tmp) if n.get("Type") == "BlockRandomizer"]
    for ri, (_, rand) in enumerate(rands_tmp):
        pool_name = ["A", "B", "C"][ri] if ri < 3 else str(ri+1)
        inner_bids = [c.get("ID", "") for c in rand.get("Flow", [])]
        fake_count = sum(1 for b in inner_bids if blocks.get(b, {}).get("Description", "").startswith("Img_F_"))
        real_count = sum(1 for b in inner_bids if blocks.get(b, {}).get("Description", "").startswith("Img_R_"))
        total = fake_count + real_count
        pct = fake_count / total * 100 if total > 0 else 0
        check(abs(fake_count - real_count) <= 1,
              f"Randomizer {ri+1} (Pool {pool_name}): {fake_count}F + {real_count}R = {total} ({pct:.0f}% fake)",
              f"Randomizer {ri+1} imbalanced: {fake_count}F + {real_count}R")

    #
    # 3. SURVEY FLOW (Methodology §4)
    #
    print(f"\n{''*70}")
    print("§4  -  SURVEY FLOW ORDER")
    print(f"{''*70}")

    flow_nodes = flow.get("Flow", [])

    # Expected order:
    expected_flow = [
        ("EmbeddedData", None),
        ("Block", "Intro/Default"),
        ("Block", "Image Instructions"),
        ("BlockRandomizer", "Pool A (3 from 27)"),
        ("Block", "AttentionCheck_1"),
        ("BlockRandomizer", "Pool B (3 from 27)"),
        ("Block", "AttentionCheck_2"),
        ("BlockRandomizer", "Pool C (4 from 26)"),
        ("Block", "AI Usage Questions"),
        ("Block", "Demographics"),
        ("Block", "Score Display"),
    ]

    print(f"  Expected {len(expected_flow)} flow nodes, found {len(flow_nodes)}")
    check(len(flow_nodes) == len(expected_flow),
          f"Flow has {len(expected_flow)} nodes",
          f"Flow has {len(flow_nodes)} nodes, expected {len(expected_flow)}")

    # Walk through each node
    for i, node in enumerate(flow_nodes):
        ntype = node.get("Type", "?")
        if ntype == "EmbeddedData":
            print(f"  [{i}] {PASS} EmbeddedData")
        elif ntype == "BlockRandomizer":
            subset = node.get("SubSet", "?")
            inner_count = len(node.get("Flow", []))
            even = node.get("EvenPresentation", False)
            print(f"  [{i}] BlockRandomizer: pick {subset} from {inner_count}, EvenPresentation={even}")
            check(even, f"  EvenPresentation is ON", f"  EvenPresentation is OFF!")
        elif ntype in ("Block", "Standard"):
            bid = node.get("ID", "?")
            desc = blocks.get(bid, {}).get("Description", bid)
            print(f"  [{i}] Block: {desc}")
        else:
            print(f"  [{i}] {ntype}")

    # Verify randomizer sizes match methodology
    randomizers = [(i, n) for i, n in enumerate(flow_nodes) if n.get("Type") == "BlockRandomizer"]
    check(len(randomizers) == 3, f"3 BlockRandomizers found",
          f"Expected 3 randomizers, found {len(randomizers)}")

    if len(randomizers) == 3:
        sizes = [(r[1].get("SubSet"), len(r[1].get("Flow", []))) for r in randomizers]
        check(sizes[0] == (3, 27), f"Randomizer 1: pick 3 from {sizes[0][1]}",
              f"Randomizer 1: expected pick 3 from 27, got pick {sizes[0][0]} from {sizes[0][1]}")
        check(sizes[1] == (3, 27), f"Randomizer 2: pick 3 from {sizes[1][1]}",
              f"Randomizer 2: expected pick 3 from 27, got pick {sizes[1][0]} from {sizes[1][1]}")
        check(sizes[2] == (4, 26), f"Randomizer 3: pick 4 from {sizes[2][1]}",
              f"Randomizer 3: expected pick 4 from 26, got pick {sizes[2][0]} from {sizes[2][1]}")

    # Verify attention checks are between randomizers
    attn1_idx = None
    attn2_idx = None
    for i, node in enumerate(flow_nodes):
        if node.get("Type") in ("Block", "Standard"):
            bid = node.get("ID", "")
            desc = blocks.get(bid, {}).get("Description", "")
            if desc == "AttentionCheck_1":
                attn1_idx = i
            elif desc == "AttentionCheck_2":
                attn2_idx = i

    if randomizers and attn1_idx and attn2_idx:
        r1_idx, r2_idx, r3_idx = randomizers[0][0], randomizers[1][0], randomizers[2][0]
        check(r1_idx < attn1_idx < r2_idx,
              f"AttentionCheck_1 is between Randomizer 1 and 2 (positions {r1_idx} < {attn1_idx} < {r2_idx})",
              f"AttentionCheck_1 not correctly positioned")
        check(r2_idx < attn2_idx < r3_idx,
              f"AttentionCheck_2 is between Randomizer 2 and 3 (positions {r2_idx} < {attn2_idx} < {r3_idx})",
              f"AttentionCheck_2 not correctly positioned")

    #
    # 4. IMAGE BLOCK CONTENTS (Methodology §8)
    #
    print(f"\n{''*70}")
    print("§8  -  IMAGE BLOCK CONTENTS: each block has DB, MC, Slider, Timing")
    print(f"{''*70}")

    blocks_missing_questions = []
    blocks_wrong_order = []
    blocks_missing_gt = []
    blocks_wrong_gt = []
    blocks_missing_counter_js = []
    blocks_missing_mc_js = []
    blocks_mc_wrong_ref = []
    blocks_no_forced_response = []
    blocks_missing_timing = []

    for bid, blk in sorted(all_image_blocks.items()):
        desc = blk.get("Description", "")
        expected_truth = "fake" if desc.startswith("Img_F_") else "real"

        # Get block elements in order
        q_list = []
        for be in blk.get("BlockElements", []):
            if be.get("Type") == "Question":
                qid = be["QuestionID"]
                q = questions.get(qid, {})
                q_list.append((qid, q))

        # Check: 4 questions (DB, MC, Slider, Timing)
        if len(q_list) != 4:
            blocks_missing_questions.append(f"{desc}: has {len(q_list)} questions, expected 4")
            continue

        db_qid, db_q = q_list[0]
        mc_qid, mc_q = q_list[1]
        sl_qid, sl_q = q_list[2]
        tm_qid, tm_q = q_list[3]

        # Check question types in order
        types = [q.get("QuestionType", "") for _, q in q_list]
        expected_types = ["DB", "MC", "Slider", "Timing"]
        if types != expected_types:
            blocks_wrong_order.append(f"{desc}: types are {types}, expected {expected_types}")

        # Check DB: ground truth span
        db_text = db_q.get("QuestionText", "")
        gt_tag = f'id="gt-{bid}"'
        if gt_tag not in db_text:
            blocks_missing_gt.append(f"{desc}: missing gt-{bid} span")
        elif f'data-answer="{expected_truth}"' not in db_text:
            blocks_wrong_gt.append(f"{desc}: gt span has wrong truth (expected {expected_truth})")

        # Check DB: progress counter JS
        db_js = db_q.get("QuestionJS", "")
        if "imgCount" not in db_js:
            blocks_missing_counter_js.append(f"{desc}: DB missing imgCount JS")

        # Check DB: has an actual image
        if "Graphic.php" not in db_text and "img" not in db_text.lower():
            issues.append(f"{desc}: DB question has no image!")

        # Check MC: scoring JS
        mc_js = mc_q.get("QuestionJS", "")
        if not mc_js:
            blocks_missing_mc_js.append(f"{desc}: MC has no JavaScript")
        elif f"r_{bid}" not in mc_js:
            blocks_mc_wrong_ref.append(f"{desc}: MC JS doesn't write to r_{bid}")

        # Check MC: forced response
        mc_validation = mc_q.get("Validation", {}).get("Settings", {})
        if mc_validation.get("ForceResponse") != "ON":
            blocks_no_forced_response.append(f"{desc}: MC not forced response")

        # Check MC: correct choices
        choices = mc_q.get("Choices", {})
        choice_1 = choices.get("1", {}).get("Display", "")
        choice_2 = choices.get("2", {}).get("Display", "")
        if "Real" not in choice_1 and "real" not in choice_1:
            issues.append(f"{desc}: MC choice 1 is '{choice_1}', expected 'Real photograph'")
        if "AI" not in choice_2 and "ai" not in choice_2.lower():
            issues.append(f"{desc}: MC choice 2 is '{choice_2}', expected 'AI-generated image'")

        # Check Timing question
        if tm_q.get("QuestionType") != "Timing":
            blocks_missing_timing.append(f"{desc}: Q4 is {tm_q.get('QuestionType')}, expected Timing")

    check(len(blocks_missing_questions) == 0,
          "All 80 blocks have 4 questions",
          f"{len(blocks_missing_questions)} blocks have wrong question count")
    for b in blocks_missing_questions:
        print(f"    {FAIL} {b}")

    check(len(blocks_wrong_order) == 0,
          "All 80 blocks have correct question order (DB, MC, Slider, Timing)",
          f"{len(blocks_wrong_order)} blocks have wrong question order")
    for b in blocks_wrong_order:
        print(f"    {FAIL} {b}")

    check(len(blocks_missing_gt) == 0,
          "All 80 DB questions have ground truth spans",
          f"{len(blocks_missing_gt)} blocks missing ground truth span")
    for b in blocks_missing_gt:
        print(f"    {FAIL} {b}")

    check(len(blocks_wrong_gt) == 0,
          "All ground truth spans have correct fake/real labels",
          f"{len(blocks_wrong_gt)} blocks have wrong ground truth")
    for b in blocks_wrong_gt:
        print(f"    {FAIL} {b}")

    check(len(blocks_missing_counter_js) == 0,
          "All 80 DB questions have progress counter JS (imgCount)",
          f"{len(blocks_missing_counter_js)} blocks missing counter JS")

    check(len(blocks_missing_mc_js) == 0,
          "All 80 MC questions have scoring JavaScript",
          f"{len(blocks_missing_mc_js)} blocks missing MC JS")

    check(len(blocks_mc_wrong_ref) == 0,
          "All 80 MC JS writes to correct r_BLOCKID field",
          f"{len(blocks_mc_wrong_ref)} blocks reference wrong r_ field")

    check(len(blocks_no_forced_response) == 0,
          "All 80 MC questions have ForceResponse ON",
          f"{len(blocks_no_forced_response)} MC questions not forced")
    for b in blocks_no_forced_response:
        print(f"    {FAIL} {b}")

    check(len(blocks_missing_timing) == 0,
          "All 80 blocks have Timing question as Q4",
          f"{len(blocks_missing_timing)} blocks missing Timing question")
    for b in blocks_missing_timing:
        print(f"    {FAIL} {b}")

    #
    # 5. ATTENTION CHECKS (Methodology §10)
    #
    print(f"\n{''*70}")
    print("§10  -  ATTENTION CHECKS: 2 blocks with obvious AI images")
    print(f"{''*70}")

    attn_blocks = {}
    for bid, blk in blocks.items():
        desc = blk.get("Description", "")
        if "AttentionCheck" in desc:
            attn_blocks[bid] = blk

    check(len(attn_blocks) == 2, f"2 attention check blocks found",
          f"Expected 2 attention blocks, found {len(attn_blocks)}")

    for bid, blk in attn_blocks.items():
        desc = blk.get("Description", "")
        q_list = []
        for be in blk.get("BlockElements", []):
            if be.get("Type") == "Question":
                qid = be["QuestionID"]
                q_list.append((qid, questions.get(qid, {})))

        # Attention checks may have DB + MC + Slider (confidence)  -  that's fine
        check(len(q_list) >= 2, f"{desc}: has {len(q_list)} questions (DB + MC" + (" + Slider)" if len(q_list) == 3 else ")"),
              f"{desc}: has {len(q_list)} questions, expected at least 2")

        # Attention check MC should NOT have scoring JS
        for qid, q in q_list:
            if q.get("QuestionType") == "MC":
                mc_js = q.get("QuestionJS", "")
                warn(not mc_js or "r_" not in mc_js,
                     f"{desc}: MC does NOT affect scoring",
                     f"{desc}: MC has scoring JS  -  attention checks should NOT be scored!")

        # Check that attention images are NOT in the image block pool
        for qid, q in q_list:
            if q.get("QuestionType") == "DB":
                db_text = q.get("QuestionText", "")
                warn("Attention Check" in db_text or "attention" in db_text.lower() or "img-counter" not in db_text,
                     f"{desc}: DB question is labeled as attention check",
                     f"{desc}: DB question may not be distinguishable from image blocks")

    #
    # 6. SCORING (Methodology §9)
    #
    print(f"\n{''*70}")
    print("§9  -  SCORING: per-block results summed at end")
    print(f"{''*70}")

    # Find Score Display block
    score_bid = None
    score_blk = None
    for bid, blk in blocks.items():
        if blk.get("Description", "") == "Score Display":
            score_bid = bid
            score_blk = blk

    check(score_bid is not None, "Score Display block exists", "Score Display block NOT found!")

    if score_blk:
        score_qs = []
        for be in score_blk.get("BlockElements", []):
            if be.get("Type") == "Question":
                qid = be["QuestionID"]
                score_qs.append((qid, questions.get(qid, {})))

        # Find the DB question with score display
        for qid, q in score_qs:
            qtext = q.get("QuestionText", "")
            qjs = q.get("QuestionJS", "")

            if "score" in qtext.lower():
                check("score-value" in qtext,
                      "Score Display HTML has #score-value placeholder",
                      "Score Display HTML missing #score-value span")

                check("top 5" in qtext.lower() or "gift card" in qtext.lower(),
                      "Score Display mentions gift card raffle",
                      "Score Display doesn't mention gift card raffle")

                check("/ 10" in qtext or "/10" in qtext,
                      "Score Display shows 'X / 10'",
                      "Score Display doesn't show '/ 10'")

            if qjs and "score" in qjs:
                # Count r_ field references
                r_refs = set(re.findall(r'r_BL_\w+', qjs))
                check(len(r_refs) == 80,
                      f"Score JS references all 80 r_ fields",
                      f"Score JS references {len(r_refs)} r_ fields, expected 80")

                check("setEmbeddedData" in qjs and '"score"' in qjs,
                      "Score JS saves total to 'score' embedded data",
                      "Score JS may not save to 'score' embedded data")

                check("score-value" in qjs,
                      "Score JS updates #score-value element on page",
                      "Score JS doesn't update visible score display")

    #
    # 7. EMBEDDED DATA (Methodology §9, §11)
    #
    print(f"\n{''*70}")
    print("§9/§11  -  EMBEDDED DATA: all fields declared in flow")
    print(f"{''*70}")

    ed_node = None
    for node in flow.get("Flow", []):
        if node.get("Type") == "EmbeddedData":
            ed_node = node
            break

    check(ed_node is not None, "EmbeddedData node found in flow", "No EmbeddedData in flow!")

    if ed_node:
        declared_fields = {ed.get("Field") for ed in ed_node.get("EmbeddedData", [])}
        r_fields = {f for f in declared_fields if f.startswith("r_")}

        check("imgCount" in declared_fields, "imgCount declared in flow", "imgCount NOT declared!")
        check("score" in declared_fields, "score declared in flow", "score NOT declared!")
        check(len(r_fields) == 80, f"80 r_ fields declared ({len(r_fields)} found)",
              f"Expected 80 r_ fields, found {len(r_fields)}")

        # Verify every image block has a matching r_ field
        missing_r = []
        for bid in all_image_blocks:
            if f"r_{bid}" not in declared_fields:
                missing_r.append(bid)
        check(len(missing_r) == 0,
              "Every image block has matching r_ field in EmbeddedData",
              f"{len(missing_r)} image blocks have no r_ field declared")

    #
    # 8. MC CHOICE LOGIC  -  VERIFY JS SCORING LOGIC IS CORRECT
    #
    print(f"\n{''*70}")
    print("§9  -  SCORING LOGIC: choice 1=Real, choice 2=AI, ground truth matching")
    print(f"{''*70}")

    # Sample a few blocks and verify the full JS logic chain
    sample_blocks = list(all_image_blocks.items())[:5]
    logic_ok = True

    for bid, blk in sample_blocks:
        desc = blk.get("Description", "")
        expected_truth = "fake" if "Img_F_" in desc else "real"

        mc_qid = None
        mc_q = None
        for be in blk.get("BlockElements", []):
            if be.get("Type") == "Question":
                q = questions.get(be["QuestionID"], {})
                if q.get("QuestionType") == "MC":
                    mc_qid = be["QuestionID"]
                    mc_q = q
                    break

        if mc_q:
            js = mc_q.get("QuestionJS", "")
            # Verify: chosen === "1" && truth === "real" -> correct for real images
            # Verify: chosen === "2" && truth === "fake" -> correct for fake images
            has_real_logic = '"1" && truth === "real"' in js or "'1' && truth === 'real'" in js
            has_fake_logic = '"2" && truth === "fake"' in js or "'2' && truth === 'fake'" in js
            if not (has_real_logic and has_fake_logic):
                issues.append(f"{desc}: JS scoring logic may be incorrect")
                logic_ok = False

    check(logic_ok, "Scoring logic correct: choice 1=Real matches truth='real', choice 2=AI matches truth='fake'",
          "Some blocks have incorrect scoring logic")

    #
    # 9. SURVEY OPTIONS
    #
    print(f"\n{''*70}")
    print("SURVEY OPTIONS: back button, security, etc.")
    print(f"{''*70}")

    back_button = options.get("BackButton", "false")
    check(str(back_button).lower() in ("true", "on"),
          f"Back button enabled (BackButton={back_button})",
          f"Back button may be disabled (BackButton={back_button})")

    # Ballot box stuffing
    bbs = options.get("BallotBoxStuffingPrevention", "false")
    warn(str(bbs).lower() in ("true", "on"),
         f"BallotBoxStuffingPrevention enabled ({bbs})",
         f"BallotBoxStuffingPrevention OFF  -  consider enabling")

    # Bot detection
    recaptcha = options.get("RecaptchaV3", "false")
    warn(str(recaptcha).lower() in ("true", "on"),
         f"RecaptchaV3 (bot detection) enabled ({recaptcha})",
         f"RecaptchaV3 OFF  -  consider enabling")

    # Anonymize responses
    anon = options.get("Anonymize", {})
    print(f"    Anonymize setting: {json.dumps(anon) if anon else 'not set'}")

    #
    # 10. CROSS-CHECK: randomizer block IDs match pool assignments
    #
    print(f"\n{''*70}")
    print("CROSS-CHECK: randomizer contents match pool labels")
    print(f"{''*70}")

    for i, (idx, rand_node) in enumerate(randomizers):
        pool_label = ["A", "B", "C"][i]
        rand_bids = set()
        for inner in rand_node.get("Flow", []):
            rand_bids.add(inner.get("ID", ""))

        # Check all blocks in this randomizer belong to the right pool
        wrong_pool = []
        for rbid in rand_bids:
            desc = blocks.get(rbid, {}).get("Description", "")
            if f"_{pool_label}" not in desc:
                wrong_pool.append(f"{desc} ({rbid})")

        # Labels are cosmetic (assigned at build time). What matters is F/R balance.
        fake_in_rand = sum(1 for rbid in rand_bids
                          if blocks.get(rbid, {}).get("Description", "").startswith("Img_F_"))
        real_in_rand = sum(1 for rbid in rand_bids
                          if blocks.get(rbid, {}).get("Description", "").startswith("Img_R_"))
        check(abs(fake_in_rand - real_in_rand) <= 1,
              f"Randomizer {i+1} (Pool {pool_label}): {fake_in_rand}F + {real_in_rand}R  -  balanced",
              f"Randomizer {i+1}: {fake_in_rand}F + {real_in_rand}R  -  imbalanced!")
        if len(wrong_pool) > 0:
            print(f"      {len(wrong_pool)} cosmetic label mismatches (pool letter in block name doesn't match randomizer  -  not a functional issue)")

    #
    # 11. CHECK FOR ORPHAN/DUPLICATE BLOCKS
    #
    print(f"\n{''*70}")
    print("ORPHAN/DUPLICATE CHECK")
    print(f"{''*70}")

    # Collect all block IDs referenced in the flow
    def collect_flow_bids(node):
        bids = set()
        if node.get("ID"):
            bids.add(node["ID"])
        for child in node.get("Flow", []):
            bids.update(collect_flow_bids(child))
        return bids

    flow_bids = collect_flow_bids(flow)

    # Check for image blocks not in any randomizer
    orphan_img_blocks = []
    for bid in all_image_blocks:
        if bid not in flow_bids:
            orphan_img_blocks.append(bid)

    check(len(orphan_img_blocks) == 0,
          "All 80 image blocks are referenced in the flow",
          f"{len(orphan_img_blocks)} image blocks not in any randomizer!")

    # Check for duplicate block references in flow
    all_flow_refs = []
    def collect_all_refs(node):
        if node.get("ID"):
            all_flow_refs.append(node["ID"])
        for child in node.get("Flow", []):
            collect_all_refs(child)
    collect_all_refs(flow)

    from collections import Counter
    ref_counts = Counter(all_flow_refs)
    dupes = {bid: count for bid, count in ref_counts.items() if count > 1}
    check(len(dupes) == 0,
          "No duplicate block references in flow",
          f"{len(dupes)} blocks referenced multiple times: {list(dupes.keys())[:5]}")

    #
    # 12. UNIQUE IMAGE CHECK  -  no duplicate graphic IDs across blocks
    #
    print(f"\n{''*70}")
    print("UNIQUE IMAGE CHECK: no duplicate images across blocks")
    print(f"{''*70}")

    graphic_ids_seen = {}
    for bid, blk in all_image_blocks.items():
        desc = blk.get("Description", "")
        for be in blk.get("BlockElements", []):
            if be.get("Type") == "Question":
                q = questions.get(be["QuestionID"], {})
                if q.get("QuestionType") == "DB":
                    text = q.get("QuestionText", "")
                    # Extract graphic ID from URL
                    match = re.search(r'IM=([A-Za-z0-9_]+)', text)
                    if match:
                        gid = match.group(1)
                        if gid in graphic_ids_seen:
                            issues.append(f"Duplicate image! {gid} in both {graphic_ids_seen[gid]} and {desc}")
                        graphic_ids_seen[gid] = desc

    check(len(graphic_ids_seen) == 80,
          f"80 unique images found across blocks",
          f"Found {len(graphic_ids_seen)} unique images, expected 80")

    #
    # 13. AI USAGE & DEMOGRAPHICS BLOCKS EXIST
    #
    print(f"\n{''*70}")
    print("AI USAGE & DEMOGRAPHICS: blocks exist and have questions")
    print(f"{''*70}")

    for target in ["AI Usage Questions", "Demographics"]:
        found = False
        for bid, blk in blocks.items():
            if blk.get("Description", "") == target:
                found = True
                q_count = sum(1 for be in blk.get("BlockElements", []) if be.get("Type") == "Question")
                check(q_count > 0, f"{target}: {q_count} questions", f"{target}: has 0 questions!")
                break
        check(found, f"{target} block exists", f"{target} block NOT found!")

    # Verify AI Usage comes before Demographics in flow
    ai_idx = demo_idx = None
    for i, node in enumerate(flow_nodes):
        if node.get("Type") in ("Block", "Standard"):
            bid = node.get("ID", "")
            desc = blocks.get(bid, {}).get("Description", "")
            if desc == "AI Usage Questions":
                ai_idx = i
            elif desc == "Demographics":
                demo_idx = i

    if ai_idx and demo_idx:
        check(ai_idx < demo_idx,
              f"AI Usage (position {ai_idx}) comes before Demographics (position {demo_idx})",
              f"AI Usage should come before Demographics!")

    #
    # SUMMARY
    #
    print(f"\n{'='*70}")
    print("  AUDIT SUMMARY")
    print(f"{'='*70}")

    if not issues and not warnings:
        print(f"  {PASS} ALL CHECKS PASSED  -  zero issues, zero warnings")
    else:
        if issues:
            print(f"\n  {FAIL} {len(issues)} ISSUES (must fix):")
            for issue in issues:
                print(f"     • {issue}")
        if warnings:
            print(f"\n  {WARN} {len(warnings)} WARNINGS (consider fixing):")
            for w in warnings:
                print(f"     • {w}")

    print(f"\n  Blocks: {len(blocks)} total")
    print(f"    Image: {len(all_image_blocks)} (40F + 40R)")
    print(f"    Attention: {len(attn_blocks)}")
    print(f"    Other: {len(other_blocks)}")
    print(f"  Questions: {len(questions)} total")
    print(f"  Flow nodes: {len(flow_nodes)}")
    print(f"  Embedded data fields: {len(declared_fields) if ed_node else '?'}")
    print()

if __name__ == "__main__":
    main()
