"""`GET /staff/me`: the signed-in user's staff roles (the console's access check).

Returns an empty list for non-staff, so the console can show "no access"
without treating it as an error.
"""

from typing import Annotated

from fastapi import APIRouter, Depends

from prepvruksha_api.staff.access import StaffMember, read_roles

router = APIRouter(prefix="/staff", tags=["staff"])


@router.get("/me")
def get_me(member: Annotated[StaffMember, Depends(read_roles)]) -> StaffMember:
    return member
