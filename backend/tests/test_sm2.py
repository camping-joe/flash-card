from datetime import datetime, timezone, timedelta
from app.services.sm2 import calculate_sm2

def test_sm2_first_time_easy():
    result = calculate_sm2(repetitions=0, ease_factor=2.5, interval=0, rating=4)
    assert result["repetitions"] == 1
    # 新卡评分为 4（简单），interval = new_card_easy_interval（默认 3）
    assert result["interval"] == 3
    assert result["ease_factor"] == 2.5
    assert result["next_review_at"] > datetime.now(timezone.utc)

def test_sm2_first_time_good():
    result = calculate_sm2(repetitions=0, ease_factor=2.5, interval=0, rating=3)
    assert result["repetitions"] == 1
    # 新卡评分为 3（良好），interval = new_card_hard_interval（默认 1）
    assert result["interval"] == 1

def test_sm2_second_time_easy():
    result = calculate_sm2(repetitions=1, ease_factor=2.5, interval=1, rating=4)
    assert result["repetitions"] == 2
    assert result["interval"] == 6

def test_sm2_again():
    result = calculate_sm2(repetitions=5, ease_factor=2.5, interval=30, rating=1)
    assert result["repetitions"] == 0
    # 评分为 1（重来），interval = 0
    assert result["interval"] == 0

def test_sm2_lapsed():
    result = calculate_sm2(repetitions=0, ease_factor=2.5, interval=0, rating=2)
    assert result["repetitions"] == 0
    assert result["interval"] == 1
