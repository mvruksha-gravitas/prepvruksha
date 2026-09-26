"""Consent feature: terms and parental consent (DPDP). Public entry point."""

from prepvruksha_api.consent.codes import ParentCodeIssuer, get_code_issuer
from prepvruksha_api.consent.router import router

__all__ = ["ParentCodeIssuer", "get_code_issuer", "router"]
