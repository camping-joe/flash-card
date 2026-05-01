"""add algorithm_settings table

Revision ID: 20260428010101
Revises: 20260427234421
Create Date: 2026-04-28 01:01:01

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260428010101'
down_revision: Union[str, None] = '20260427234421'
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.create_table(
        'algorithm_settings',
        sa.Column('id', sa.Integer(), nullable=False),
        sa.Column('user_id', sa.Integer(), nullable=False),
        sa.Column('new_card_easy_interval', sa.Integer(), nullable=True),
        sa.Column('new_card_hard_interval', sa.Integer(), nullable=True),
        sa.Column('second_repetition_interval', sa.Integer(), nullable=True),
        sa.Column('min_ease_factor', sa.REAL(), nullable=True),
        sa.Column('initial_ease_factor', sa.REAL(), nullable=True),
        sa.Column('created_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.Column('updated_at', sa.TIMESTAMP(timezone=True), server_default=sa.text('now()'), nullable=True),
        sa.ForeignKeyConstraint(['user_id'], ['users.id']),
        sa.PrimaryKeyConstraint('id'),
        sa.UniqueConstraint('user_id')
    )
    op.create_index(op.f('ix_algorithm_settings_id'), 'algorithm_settings', ['id'], unique=False)


def downgrade() -> None:
    op.drop_index(op.f('ix_algorithm_settings_id'), table_name='algorithm_settings')
    op.drop_table('algorithm_settings')
