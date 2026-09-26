"""Signup state (profile → terms → parental consent) and rule-violation mapping.

The rules live in Postgres functions (supabase/migrations/*_signup_functions.sql).
Every signup endpoint returns the fresh state so the app can route from one
response, so the profile and consent features both use this module.
"""

from datetime import datetime
from typing import Annotated, Any, Literal

from fastapi import Depends, HTTPException, status
from pydantic import BaseModel

from prepvruksha_api.shared.supabase_rpc import Rpc, RuleViolationError, get_rpc

RpcDep = Annotated[Rpc, Depends(get_rpc)]

SignupStatus = Literal["needs_profile", "needs_terms", "needs_parental", "complete"]

_ERROR_STATUS: dict[str, int] = {
    "profile_not_found": status.HTTP_404_NOT_FOUND,
    "dob_already_set": status.HTTP_409_CONFLICT,
    "policy_version_outdated": status.HTTP_409_CONFLICT,
    "parental_consent_not_required": status.HTTP_409_CONFLICT,
    "no_active_consent": status.HTTP_409_CONFLICT,
    "resend_too_soon": status.HTTP_429_TOO_MANY_REQUESTS,
    "daily_limit_reached": status.HTTP_429_TOO_MANY_REQUESTS,
    "parent_phone_daily_limit_reached": status.HTTP_429_TOO_MANY_REQUESTS,
    "full_name_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "dob_required": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "age_out_of_range": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "target_exam_year_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "category_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "language_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "parent_name_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "parent_phone_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "parent_phone_is_student_phone": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "consent_type_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
}


def rule_error(code: str) -> HTTPException:
    return HTTPException(
        _ERROR_STATUS.get(code, status.HTTP_500_INTERNAL_SERVER_ERROR), detail={"code": code}
    )


def call_rule(rpc: Rpc, function: str, **params: Any) -> Any:
    try:
        return rpc.call(function, params)
    except RuleViolationError as violation:
        raise rule_error(violation.code) from violation


class PendingRequest(BaseModel):
    parent_name: str
    parent_phone_last4: str
    expires_at: datetime
    attempts_left: int
    resend_available_at: datetime


class SignupState(BaseModel):
    status: SignupStatus
    is_minor: bool | None
    terms_version: str | None
    parental_version: str | None
    pending_request: PendingRequest | None


def read_signup_state(rpc: Rpc, user_id: str) -> SignupState:
    raw = call_rule(rpc, "get_signup_state", p_user_id=user_id)
    pending = raw.get("pending_request")
    return SignupState(
        status=raw["status"],
        is_minor=raw.get("is_minor"),
        terms_version=raw.get("terms_version"),
        parental_version=raw.get("parental_version"),
        pending_request=None
        if pending is None
        else PendingRequest(
            parent_name=pending["parent_name"],
            parent_phone_last4=pending["parent_phone"][-4:],
            expires_at=pending["expires_at"],
            attempts_left=pending["attempts_left"],
            resend_available_at=pending["resend_available_at"],
        ),
    )
