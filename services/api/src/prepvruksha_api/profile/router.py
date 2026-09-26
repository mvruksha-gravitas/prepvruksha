"""Profile: signup state and profile completion (`/me/signup`, `/me/profile`)."""

from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends
from pydantic import BaseModel, Field

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.shared import RpcDep, SignupState, call_rule, read_signup_state

router = APIRouter(prefix="/me", tags=["signup"])

UserId = Annotated[str, Depends(current_user_id)]

Category = Literal["general", "ews", "obc_ncl", "sc", "st"]


@router.get("/signup")
def get_signup(user_id: UserId, rpc: RpcDep) -> SignupState:
    return read_signup_state(rpc, user_id)


class ProfileIn(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    date_of_birth: date
    target_exam_year: int
    category: Category | None = None
    preferred_language: Literal["en", "kn"] | None = None


@router.put("/profile")
def complete_profile(body: ProfileIn, user_id: UserId, rpc: RpcDep) -> SignupState:
    call_rule(
        rpc,
        "complete_profile",
        p_user_id=user_id,
        p_full_name=body.full_name,
        p_date_of_birth=body.date_of_birth.isoformat(),
        p_target_exam_year=body.target_exam_year,
        p_category=body.category,
        p_preferred_language=body.preferred_language,
    )
    return read_signup_state(rpc, user_id)
