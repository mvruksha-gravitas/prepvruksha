"""Code shared by all features: settings, Supabase RPC and Storage, phone numbers, signup state."""

from prepvruksha_api.shared.phone import normalize_indian_mobile
from prepvruksha_api.shared.settings import Settings, get_settings
from prepvruksha_api.shared.signup_state import (
    RpcDep,
    SignupState,
    call_rule,
    read_signup_state,
    rule_error,
)
from prepvruksha_api.shared.storage import Storage, StorageDep, get_storage
from prepvruksha_api.shared.supabase_rpc import Rpc, RuleViolationError, get_rpc

__all__ = [
    "Rpc",
    "RpcDep",
    "RuleViolationError",
    "Settings",
    "SignupState",
    "Storage",
    "StorageDep",
    "call_rule",
    "get_rpc",
    "get_settings",
    "get_storage",
    "normalize_indian_mobile",
    "read_signup_state",
    "rule_error",
]
