import asyncio
import asyncpg
import os
from dotenv import load_dotenv

load_dotenv()

DATABASE_URL = os.getenv("DATABASE_URL").replace("+asyncpg", "")

async def migrate():
    conn = await asyncpg.connect(DATABASE_URL)

    # 1. Create libraries table
    await conn.execute("""
        CREATE TABLE IF NOT EXISTS libraries (
            id SERIAL PRIMARY KEY,
            name VARCHAR(255) NOT NULL,
            description TEXT,
            user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
            created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
            updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
        )
    """)

    # 2. Create unique index on (name, user_id)
    await conn.execute("""
        CREATE UNIQUE INDEX IF NOT EXISTS idx_libraries_name_user
        ON libraries (name, user_id)
    """)

    # 3. Migrate notes into libraries (one library per note title per user)
    await conn.execute("""
        INSERT INTO libraries (name, user_id, created_at, updated_at)
        SELECT DISTINCT ON (title, user_id)
            title, user_id, created_at, updated_at
        FROM notes
        ON CONFLICT (name, user_id) DO NOTHING
    """)

    # 4. Add library_id to notes
    await conn.execute("""
        ALTER TABLE notes
        ADD COLUMN IF NOT EXISTS library_id INTEGER REFERENCES libraries(id) ON DELETE SET NULL
    """)

    await conn.execute("""
        UPDATE notes
        SET library_id = libraries.id
        FROM libraries
        WHERE notes.title = libraries.name AND notes.user_id = libraries.user_id
    """)

    # 5. Add library_id to flashcards
    await conn.execute("""
        ALTER TABLE flashcards
        ADD COLUMN IF NOT EXISTS library_id INTEGER
    """)

    await conn.execute("""
        UPDATE flashcards
        SET library_id = notes.library_id
        FROM notes
        WHERE flashcards.note_id = notes.id
    """)

    # 6. Set not null and add foreign key for flashcards.library_id
    # First handle any flashcards that still have null library_id (orphaned cards)
    # Assign them to a default "未分类" library for their user
    orphaned = await conn.fetch("""
        SELECT DISTINCT user_id FROM flashcards WHERE library_id IS NULL
    """)
    for row in orphaned:
        user_id = row["user_id"]
        lib_id = await conn.fetchval("""
            INSERT INTO libraries (name, user_id)
            VALUES ('未分类', $1)
            ON CONFLICT (name, user_id) DO UPDATE SET name = '未分类'
            RETURNING id
        """, user_id)
        await conn.execute("""
            UPDATE flashcards SET library_id = $1 WHERE library_id IS NULL AND user_id = $2
        """, lib_id, user_id)

    await conn.execute("""
        ALTER TABLE flashcards ALTER COLUMN library_id SET NOT NULL
    """)

    await conn.execute("""
        ALTER TABLE flashcards
        ADD CONSTRAINT fk_flashcards_library
        FOREIGN KEY (library_id) REFERENCES libraries(id) ON DELETE CASCADE
    """)

    # 7. Drop old note_id column and constraints from flashcards
    await conn.execute("""
        ALTER TABLE flashcards DROP COLUMN IF EXISTS note_id
    """)

    # 8. Add trigger for updated_at on libraries
    await conn.execute("""
        CREATE OR REPLACE FUNCTION update_updated_at_column()
        RETURNS TRIGGER AS $$
        BEGIN
            NEW.updated_at = NOW();
            RETURN NEW;
        END;
        $$ language 'plpgsql';
    """)

    await conn.execute("""
        DROP TRIGGER IF EXISTS update_libraries_updated_at ON libraries;
        CREATE TRIGGER update_libraries_updated_at
            BEFORE UPDATE ON libraries
            FOR EACH ROW
            EXECUTE FUNCTION update_updated_at_column();
    """)

    await conn.close()
    print("Migration completed successfully")

if __name__ == "__main__":
    asyncio.run(migrate())
