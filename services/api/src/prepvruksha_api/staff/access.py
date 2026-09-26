"""Staff access: the one dependency every staff endpoint goes through.

Production rules for staff (e.g. requiring Google sign-in with 2-step
verification, a launch blocker in docs/STATUS.md) are enforced here, so no
endpoint has to change when they are added.
"""

from typing import Annotated, Literal

from fastapi import Depends, HTTPException, status
from pydantic import BaseModel

from prepvruksha_api.auth import current_user_id
from prepvruksha_api.shared import RpcDep, call_rule

StaffRole = Literal["reviewer", "content_admin", "super_admin"]


class StaffMember(BaseModel):
    user_id: str
    roles: list[StaffRole]

    def has(self, role: StaffRole) -> bool:
        """super_admin satisfies every role, as in the database."""
        return role in self.roles or "super_admin" in self.roles


# The token is checked first, so unsigned requests never reach Supabase.
def read_roles(user_id: Annotated[str, Depends(current_user_id)], rpc: RpcDep) -> StaffMember:
    roles = call_rule(rpc, "get_staff_roles", p_user_id=user_id) or []
    return StaffMember(user_id=user_id, roles=roles)


def current_staff(member: Annotated[StaffMember, Depends(read_roles)]) -> StaffMember:
    if not member.roles:
        raise HTTPException(status.HTTP_403_FORBIDDEN, detail={"code": "not_staff"})
    return member


Staff = Annotated[StaffMember, Depends(current_staff)]
