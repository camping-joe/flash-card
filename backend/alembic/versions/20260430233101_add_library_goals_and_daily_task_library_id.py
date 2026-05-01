"""add library goals and daily task library id

Revision ID: 20260430233101
Revises: 20260428010101
Create Date: 2026-04-30 23:31:01

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260430233101'
down_revision: Union[str, None] = '20260428010101'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # libraries 表增加每日目标字段
    op.add_column('libraries', sa.Column('daily_new_cards', sa.Integer(), nullable=True))
    op.add_column('libraries', sa.Column('daily_review_limit', sa.Integer(), nullable=True))

    # daily_tasks 表增加 library_id 字段
    op.add_column('daily_tasks', sa.Column('library_id', sa.Integer(), nullable=True))
    op.create_foreign_key(
        'fk_daily_tasks_library',
        'daily_tasks',
        'libraries',
        ['library_id'],
        ['id'],
        ondelete='CASCADE'
    )


def downgrade() -> None:
    op.drop_constraint('fk_daily_tasks_library', 'daily_tasks', type_='foreignkey')
    op.drop_column('daily_tasks', 'library_id')
    op.drop_column('libraries', 'daily_review_limit')
    op.drop_column('libraries', 'daily_new_cards')
