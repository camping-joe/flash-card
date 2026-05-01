import json

def mock_ai_extractor(content: str):
    """模拟 Pi 上 ai_extractor.py 的处理逻辑"""
    content = content.strip()
    if content.startswith("```json"):
        content = content[7:]
    if content.startswith("```"):
        content = content[3:]
    if content.endswith("```"):
        content = content[:-3]
    content = content.strip()
    cards = json.loads(content)
    valid_cards = []
    for card in cards:
        if isinstance(card, dict) and card.get('front') and card.get('back'):
            valid_cards.append({
                'front': str(card['front']).strip(),
                'back': str(card['back']).strip()
            })
    return valid_cards

def mock_admin_run_extraction(cards):
    """模拟 admin.py 中 _run_extraction 的卡片处理逻辑"""
    if not cards:
        return "failed: AI returned no valid flashcards"

    created_count = 0
    for card_data in cards:
        try:
            front = card_data["front"]
            back = card_data["back"]
            created_count += 1
        except Exception as card_err:
            pass

    if created_count == 0:
        return "failed: all cards invalid"
    return f"completed: {created_count} cards"

test_cases = [
    ("正常数组", '[{"front": "Q1", "back": "A1"}]'),
    ("空 front", '[{"front": "", "back": "A1"}]'),
    ("缺少 front", '[{"back": "A1"}]'),
    ("错误键名", '[{"question": "Q1", "answer": "A1"}]'),
    ("单个对象非数组", '{"front": "Q1", "back": "A1"}'),
    ("嵌套对象", '{"flashcards": [{"front": "Q1", "back": "A1"}]}'),
    ("嵌套数组", '[[{"front": "Q1", "back": "A1"}]]'),
    ("字符串非JSON", 'not json at all'),
    ("空数组", '[]'),
    ("混合有效无效", '[{"front": "Q1", "back": "A1"}, {"question": "Q2", "answer": "A2"}]'),
    ("AI加了说明文字", 'Here are the cards:\n```json\n[{"front": "Q1", "back": "A1"}]\n```'),
    ("对象value为数组", '{"data": [{"front": "Q1", "back": "A1"}]}'),
]

print("=" * 70)
print("测试 ai_extractor 处理逻辑")
print("=" * 70)
for name, raw in test_cases:
    try:
        result = mock_ai_extractor(raw)
        status = mock_admin_run_extraction(result)
        print(f"OK  [{name:20s}] -> extractor={result!r}, admin={status}")
    except Exception as e:
        print(f"ERR [{name:20s}] -> {type(e).__name__}: {e}")

print()
print("=" * 70)
print("测试如果 extractor 返回的是 dict 而非 list")
print("=" * 70)
# 模拟如果 json.loads 返回 dict，for card in dict 会发生什么
test_dicts = [
    ("单层dict", {"front": "Q1", "back": "A1"}),
    ("嵌套dict", {"flashcards": [{"front": "Q1", "back": "A1"}]}),
]
for name, obj in test_dicts:
    try:
        valid_cards = []
        for card in obj:
            if isinstance(card, dict) and card.get('front') and card.get('back'):
                valid_cards.append({
                    'front': str(card['front']).strip(),
                    'back': str(card['back']).strip()
                })
        status = mock_admin_run_extraction(valid_cards)
        print(f"OK  [{name:20s}] -> extractor={valid_cards!r}, admin={status}")
    except Exception as e:
        print(f"ERR [{name:20s}] -> {type(e).__name__}: {e}")
