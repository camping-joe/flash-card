"""add progress_message to extraction_jobs

Revision ID: 20260427234421
Revises:
Create Date: 2026-04-27 23:44:21

"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '20260427234421'
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    op.add_column('extraction_jobs', sa.Column('progress_message', sa.Text(), nullable=True))


def downgrade() -> None:
    op.drop_column('extraction_jobs', 'progress_message')
