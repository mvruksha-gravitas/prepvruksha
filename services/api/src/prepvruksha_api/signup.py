"""Signup: profile completion, terms and parental consent (DPDP).

The rules live in Postgres functions (supabase/migrations/*_signup_functions.sql);
this router verifies the user, generates and sends parent codes, and maps
rule violations to HTTP errors. Every call returns the fresh signup state so
the app can route from one response.
"""

from datetime import date, datetime
from typing import Annotated, Any, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.otp import ParentCodeIssuer, get_code_issuer
from prepvruksha_api.phone import normalize_indian_mobile
from prepvruksha_api.supabase_rpc import Rpc, RuleViolationError, get_rpc

router = APIRouter(prefix="/me", tags=["signup"])

UserId = Annotated[str, Depends(current_user_id)]
RpcDep = Annotated[Rpc, Depends(get_rpc)]

SignupStatus = Literal["needs_profile", "needs_terms", "needs_parental", "complete"]
Category = Literal["general", "ews", "obc_ncl", "sc", "st"]

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


def _rule_error(code: str) -> HTTPException:
    return HTTPException(
        _ERROR_STATUS.get(code, status.HTTP_500_INTERNAL_SERVER_ERROR), detail={"code": code}
    )


def _call(rpc: Rpc, function: str, **params: Any) -> Any:
    try:
        return rpc.call(function, params)
    except RuleViolationError as violation:
        raise _rule_error(violation.code) from violation


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


def _state(rpc: Rpc, user_id: str) -> SignupState:
    raw = _call(rpc, "get_signup_state", p_user_id=user_id)
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


@router.get("/signup")
def get_signup(user_id: UserId, rpc: RpcDep) -> SignupState:
    return _state(rpc, user_id)


class ProfileIn(BaseModel):
    full_name: str = Field(min_length=1, max_length=120)
    date_of_birth: date
    target_exam_year: int
    category: Category | None = None
    preferred_language: Literal["en", "kn"] | None = None


@router.put("/profile")
def complete_profile(body: ProfileIn, user_id: UserId, rpc: RpcDep) -> SignupState:
    _call(
        rpc,
        "complete_profile",
        p_user_id=user_id,
        p_full_name=body.full_name,
        p_date_of_birth=body.date_of_birth.isoformat(),
        p_target_exam_year=body.target_exam_year,
        p_category=body.category,
        p_preferred_language=body.preferred_language,
    )
    return _state(rpc, user_id)


class TermsIn(BaseModel):
    policy_version: str = Field(min_length=1, max_length=40)


@router.post("/consents/terms")
def accept_terms(body: TermsIn, user_id: UserId, rpc: RpcDep) -> SignupState:
    _call(rpc, "accept_terms", p_user_id=user_id, p_policy_version=body.policy_version)
    return _state(rpc, user_id)


class ParentIn(BaseModel):
    parent_name: str = Field(min_length=1, max_length=120)
    parent_phone: str = Field(min_length=10, max_length=20)


@router.post("/consents/parental")
def start_parental_consent(
    body: ParentIn,
    user_id: UserId,
    rpc: RpcDep,
    issuer: Annotated[ParentCodeIssuer, Depends(get_code_issuer)],
) -> SignupState:
    """Send a code to the parent (also used to resend or change the number)."""
    phone = normalize_indian_mobile(body.parent_phone)
    if phone is None:
        raise _rule_error("parent_phone_invalid")
    code = issuer.new_code(phone)
    _call(
        rpc,
        "start_parental_consent",
        p_user_id=user_id,
        p_parent_name=body.parent_name,
        p_parent_phone=phone,
        p_code_hash=issuer.hash(user_id, code),
    )
    # If sending fails the request stays pending with a code nobody has; the
    # student can resend after the cooldown.
    try:
        issuer.send(phone, code)
    except Exception as error:
        raise HTTPException(
            status.HTTP_502_BAD_GATEWAY, detail={"code": "code_not_sent"}
        ) from error
    return _state(rpc, user_id)


class CodeIn(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")


class VerifyOut(BaseModel):
    result: Literal[
        "verified", "invalid", "locked", "expired", "no_pending_request", "not_required"
    ]
    attempts_left: int | None = None
    state: SignupState


@router.post("/consents/parental/verify")
def verify_parental_consent(
    body: CodeIn,
    user_id: UserId,
    rpc: RpcDep,
    issuer: Annotated[ParentCodeIssuer, Depends(get_code_issuer)],
) -> VerifyOut:
    raw = _call(
        rpc,
        "verify_parental_consent",
        p_user_id=user_id,
        p_code_hash=issuer.hash(user_id, body.code),
    )
    return VerifyOut(
        result=raw["result"], attempts_left=raw.get("attempts_left"), state=_state(rpc, user_id)
    )


@router.post("/consents/{consent_type}/withdraw")
def withdraw_consent(
    consent_type: Literal["terms", "parental"], user_id: UserId, rpc: RpcDep
) -> SignupState:
    _call(rpc, "withdraw_consent", p_user_id=user_id, p_type=consent_type)
    return _state(rpc, user_id)
