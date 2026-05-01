import json
import httpx
import re

EXTRACTION_PROMPT = """You are an expert flashcard generator. Your task is to analyze the following section of notes and create high-quality review flashcards.

Rules:
1. Focus ONLY on the MOST IMPORTANT concepts in this section — things that would be forgotten without active review.
2. Prioritize: definitions, core principles, key facts, cause-effect relationships, and distinctions between similar concepts.
3. Skip trivial details, obvious statements, and things that are easy to remember without effort.
4. Each flashcard must have a clear, self-contained question (front) and a concise but complete answer (back).
5. The question should force active recall, not passive recognition. Prefer "What is X?" / "Why does X happen?" / "How is X different from Y?"
6. Generate at most {max_per_section} flashcards for this section. If the section has little valuable content, generate fewer.
7. Output ONLY a JSON array in this exact format: [{{"front": "...", "back": "..."}}]
8. If this section has no content worth reviewing, return an empty array: []
9. CRITICAL: The notes are in Chinese. You MUST generate ALL flashcards in Chinese. Both front (question) and back (answer) must be written in Chinese.

Section content:
{content}
"""


def _strip_markdown_code_blocks(text: str) -> str:
    text = text.strip()
    if text.startswith("```json"):
        text = text[7:]
    elif text.startswith("```"):
        text = text[3:]
    if text.endswith("```"):
        text = text[:-3]
    return text.strip()


def _extract_json_array(text: str):
    """从文本中提取 JSON 数组，处理 AI 在代码块外加说明文字的情况。"""
    text = _strip_markdown_code_blocks(text)
    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    # 尝试定位最外层的一对 [ ]
    start = text.find("[")
    end = text.rfind("]")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            pass

    # 尝试定位最外层的一对 { }
    start = text.find("{")
    end = text.rfind("}")
    if start != -1 and end != -1 and end > start:
        try:
            return json.loads(text[start:end + 1])
        except json.JSONDecodeError:
            pass

    return None


def _normalize_to_list(data):
    """将 AI 返回的各种格式归一化为卡片列表。"""
    if isinstance(data, list):
        return data

    if isinstance(data, dict):
        # 尝试从常见键中提取列表
        for key in ("flashcards", "cards", "data", "result", "results"):
            if key in data and isinstance(data[key], list):
                return data[key]
        # 如果字典本身像一张卡片，包装成单元素列表
        if "front" in data and "back" in data:
            return [data]
        return []

    return []


def _is_heading_line(line: str) -> bool:
    """判断一行是否是 Markdown 标题。"""
    stripped = line.lstrip()
    if not stripped:
        return False
    if stripped.startswith("#"):
        # 确保 # 后面有空格或也是 #
        after_hashes = stripped.lstrip("#")
        if after_hashes and after_hashes[0] == " ":
            return True
    return False


def split_by_sections(content: str, min_section_length: int = 50):
    """按 Markdown 标题将笔记拆分为章节列表。返回 [(section_title, section_content), ...]。
    如果没有标题，返回 [(None, content)]。"""
    lines = content.splitlines()
    if not lines:
        return [(None, content)]

    sections = []
    current_title = None
    current_lines = []

    for line in lines:
        if _is_heading_line(line):
            # 保存上一章节
            if current_lines:
                section_text = "\n".join(current_lines).strip()
                if len(section_text) >= min_section_length:
                    sections.append((current_title, section_text))
            # 新章节以标题行作为开头
            current_title = line.strip()
            current_lines = [line]
        else:
            current_lines.append(line)

    # 保存最后一个章节
    if current_lines:
        section_text = "\n".join(current_lines).strip()
        if len(section_text) >= min_section_length:
            sections.append((current_title, section_text))

    if not sections:
        # 回退：整篇作为一个章节
        return [(None, content.strip())]

    return sections


async def extract_flashcards_from_section(
    section_content: str,
    api_key: str,
    base_url: str,
    model: str,
    temperature: float,
    max_tokens: int,
    max_per_section: int = 4,
) -> list:
    """对单个章节调用 AI 生成闪卡。"""
    prompt = EXTRACTION_PROMPT.format(
        content=section_content,
        max_per_section=max_per_section,
    )
    async with httpx.AsyncClient(timeout=60.0) as client:
        response = await client.post(
            f"{base_url}/chat/completions",
            headers={"Authorization": f"Bearer {api_key}", "Content-Type": "application/json"},
            json={
                "model": model,
                "messages": [{"role": "user", "content": prompt}],
                "temperature": temperature,
                "max_tokens": max_tokens,
            },
        )
        response.raise_for_status()
        data = response.json()

        try:
            content = data["choices"][0]["message"]["content"]
        except (KeyError, IndexError, TypeError) as e:
            raise RuntimeError(f"AI API response malformed: {e}") from e

        raw = _extract_json_array(content)
        if raw is None:
            return []

        cards = _normalize_to_list(raw)
        if not isinstance(cards, list):
            return []

        valid_cards = []
        for card in cards:
            if not isinstance(card, dict):
                continue
            front = card.get("front")
            back = card.get("back")
            if front and back:
                valid_cards.append({
                    "front": str(front).strip(),
                    "back": str(back).strip(),
                })
        # 限制单章节数量
        return valid_cards[:max_per_section]


async def extract_flashcards(
    note_content: str,
    api_key: str,
    base_url: str,
    model: str,
    temperature: float,
    max_tokens: int,
    max_per_section: int = 4,
    on_progress=None,
) -> list:
    """按章节拆分笔记，逐章调用 AI 生成闪卡，确保各章节均匀覆盖。"""
    sections = split_by_sections(note_content)
    total = len(sections)

    all_cards = []
    for idx, (title, section_text) in enumerate(sections):
        if on_progress:
            await on_progress(idx + 1, total, title or f"第{idx + 1}部分")
        cards = await extract_flashcards_from_section(
            section_text,
            api_key,
            base_url,
            model,
            temperature,
            max_tokens,
            max_per_section=max_per_section,
        )
        all_cards.extend(cards)

    # 如果按章节拆分后完全没有结果（极少见），回退到整体生成一次
    if not all_cards:
        if on_progress:
            await on_progress(0, 1, "整体分析")
        cards = await extract_flashcards_from_section(
            note_content,
            api_key,
            base_url,
            model,
            temperature,
            max_tokens,
            max_per_section=max_per_section * 2,
        )
        all_cards.extend(cards)

    return all_cards
