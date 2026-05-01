from datetime import datetime, timezone, timedelta

def calculate_sm2(
    repetitions: int,
    ease_factor: float,
    interval: int,
    rating: int,
    new_card_easy_interval: int = 3,
    new_card_hard_interval: int = 1,
    second_repetition_interval: int = 6,
    min_ease_factor: float = 1.3,
) -> dict:
    if rating < 3:
        repetitions = 0
        interval = 0 if rating == 1 else new_card_hard_interval
    else:
        if repetitions == 0:
            interval = new_card_easy_interval if rating == 4 else new_card_hard_interval
        elif repetitions == 1:
            interval = second_repetition_interval
        else:
            interval = round(interval * ease_factor)
        repetitions += 1

    ease_factor = max(min_ease_factor, ease_factor + 0.1 - (5 - rating) * (0.08 + (5 - rating) * 0.02))
    next_review_at = datetime.now(timezone.utc) + timedelta(days=interval)

    return {
        "repetitions": repetitions,
        "ease_factor": ease_factor,
        "interval": interval,
        "next_review_at": next_review_at
    }
