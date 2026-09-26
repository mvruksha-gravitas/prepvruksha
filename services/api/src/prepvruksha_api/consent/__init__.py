"""Consent feature: terms and parental consent (DPDP). Public entry point."""

from prepvruksha_api.consent.codes import ParentCodeIssuer, get_code_issuer
from prepvruksha_api.consent.config import check_production_safety
from prepvruksha_api.consent.router import router

__all__ = ["ParentCodeIssuer", "check_production_safety", "get_code_issuer", "router"]
