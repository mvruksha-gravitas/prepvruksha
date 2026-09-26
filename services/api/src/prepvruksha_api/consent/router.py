"""Consent: terms and parental consent (DPDP).

The rules live in Postgres functions (supabase/migrations/*_signup_functions.sql);
this router verifies the user, generates and sends parent codes, and maps
rule violations to HTTP errors. Every call returns the fresh signup state.
"""

from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, Field

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.consent.codes import ParentCodeIssuer, get_code_issuer
from prepvruksha_api.shared import (
    RpcDep,
    SignupState,
    call_rule,
    normalize_indian_mobile,
    read_signup_state,
    rule_error,
)

router = APIRouter(prefix="/me", tags=["signup"])

UserId = Annotated[str, Depends(current_user_id)]


class TermsIn(BaseModel):
    policy_version: str = Field(min_length=1, max_length=40)


@router.post("/consents/terms")
def accept_terms(body: TermsIn, user_id: UserId, rpc: RpcDep) -> SignupState:
    call_rule(rpc, "accept_terms", p_user_id=user_id, p_policy_version=body.policy_version)
    return read_signup_state(rpc, user_id)


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
        raise rule_error("parent_phone_invalid")
    code = issuer.new_code(phone)
    call_rule(
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
    return read_signup_state(rpc, user_id)


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
    raw = call_rule(
        rpc,
        "verify_parental_consent",
        p_user_id=user_id,
        p_code_hash=issuer.hash(user_id, body.code),
    )
    return VerifyOut(
        result=raw["result"],
        attempts_left=raw.get("attempts_left"),
        state=read_signup_state(rpc, user_id),
    )


@router.post("/consents/{consent_type}/withdraw")
def withdraw_consent(
    consent_type: Literal["terms", "parental"], user_id: UserId, rpc: RpcDep
) -> SignupState:
    call_rule(rpc, "withdraw_consent", p_user_id=user_id, p_type=consent_type)
    return read_signup_state(rpc, user_id)
