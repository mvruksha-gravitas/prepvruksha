"""Code shared by all features: settings, Supabase RPC, phone numbers, signup state."""

from prepvruksha_api.shared.phone import normalize_indian_mobile
from prepvruksha_api.shared.settings import Settings, get_settings
from prepvruksha_api.shared.signup_state import (
    RpcDep,
    SignupState,
    call_rule,
    read_signup_state,
    rule_error,
)
from prepvruksha_api.shared.supabase_rpc import Rpc, RuleViolationError, get_rpc

__all__ = [
    "Rpc",
    "RpcDep",
    "RuleViolationError",
    "Settings",
    "SignupState",
    "call_rule",
    "get_rpc",
    "get_settings",
    "normalize_indian_mobile",
    "read_signup_state",
    "rule_error",
]
