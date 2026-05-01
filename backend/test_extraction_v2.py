import json
import sys
sys.path.insert(0, 'C:/Users/joe/claude-code/backend')

from app.services.ai_extractor import _extract_json_array, _normalize_to_list

test_cases = [
    ("正常数组", '[{"front": "Q1", "back": "A1"}]'),
    ("AI加说明文字", 'Here are the cards:\n```json\n[{"front": "Q1", "back": "A1"}]\n```'),
    ("AI加说明文字2", 'Sure! Here are flashcards:\n```\n[{"front": "Q1", "back": "A1"}]\n```\nHope this helps!'),
    ("单个对象", '{"front": "Q1", "back": "A1"}'),
    ("嵌套对象", '{"flashcards": [{"front": "Q1", "back": "A1"}]}'),
    ("嵌套data", '{"data": [{"front": "Q1", "back": "A1"}]}'),
    ("空 front", '[{"front": "", "back": "A1"}]'),
    ("缺少 front", '[{"back": "A1"}]'),
    ("错误键名", '[{"question": "Q1", "answer": "A1"}]'),
    ("非JSON", 'not json at all'),
    ("空数组", '[]'),
    ("混合", '[{"front": "Q1", "back": "A1"}, {"question": "Q2", "answer": "A2"}]'),
    ("双层嵌套", '{"result": {"cards": [{"front": "Q1", "back": "A1"}]}}'),
]

print("=" * 70)
print("测试 _extract_json_array + _normalize_to_list")
print("=" * 70)
for name, raw in test_cases:
    try:
        raw_parsed = _extract_json_array(raw)
        cards = _normalize_to_list(raw_parsed)
        if cards is None:
            cards = []
        valid = []
        for card in cards:
            if isinstance(card, dict) and card.get('front') and card.get('back'):
                valid.append({'front': str(card['front']).strip(), 'back': str(card['back']).strip()})
        print(f"OK  [{name:25s}] -> {len(valid)} valid cards")
    except Exception as e:
        print(f"ERR [{name:25s}] -> {type(e).__name__}: {e}")

print()
print("=" * 70)
print("测试 admin.py 处理逻辑（模拟）")
print("=" * 70)

def mock_admin_process(cards):
    if not isinstance(cards, list):
        return f"failed: unexpected type {type(cards).__name__}"
    if not cards:
        return "failed: no valid flashcards"
    created = 0
    for card_data in cards:
        if not isinstance(card_data, dict):
            continue
        front = card_data.get("front")
        back = card_data.get("back")
        if not front or not back:
            continue
        created += 1
    return f"completed: {created} cards"

for name, raw in test_cases:
    try:
        raw_parsed = _extract_json_array(raw)
        cards = _normalize_to_list(raw_parsed)
        if cards is None:
            cards = []
        result = mock_admin_process(cards)
        print(f"OK  [{name:25s}] -> {result}")
    except Exception as e:
        print(f"ERR [{name:25s}] -> {type(e).__name__}: {e}")
