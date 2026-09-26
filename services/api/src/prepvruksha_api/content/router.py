"""Content: uploaded source files for the import pipeline (`/content/files`).

Upload flow: `POST /content/files` records the file (rights status required)
and returns a signed upload URL; the browser PUTs the file there; then
`POST /content/files/{id}/complete` checks the object and queues the import.
The rules (roles, validation, visibility, audit) live in Postgres functions;
this module checks the request shape and maps rule codes to HTTP errors.
"""

from datetime import datetime
from typing import Annotated, Any, Literal

from fastapi import APIRouter, HTTPException, Query, status
from pydantic import BaseModel, Field, model_validator

from prepvruksha_api.content.config import MAX_FILE_BYTES, SOURCE_FILES_BUCKET
from prepvruksha_api.shared import Rpc, RpcDep, RuleViolationError, StorageDep
from prepvruksha_api.staff import Staff, StaffMember

router = APIRouter(prefix="/content", tags=["content"])

FileType = Literal["pdf", "docx"]
RightsStatus = Literal["owned_licensed", "official_pyq", "reference_only"]
FileStatus = Literal[
    "awaiting_upload", "queued", "extracting", "parsing", "needs_review", "done", "failed"
]

_ERROR_STATUS: dict[str, int] = {
    "not_authorised": status.HTTP_403_FORBIDDEN,
    "file_not_found": status.HTTP_404_NOT_FOUND,
    "duplicate_file": status.HTTP_409_CONFLICT,
    "file_already_uploaded": status.HTTP_409_CONFLICT,
    "upload_missing": status.HTTP_409_CONFLICT,
    "upload_size_mismatch": status.HTTP_409_CONFLICT,
    "rights_locked_by_published_questions": status.HTTP_409_CONFLICT,
    "file_type_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "file_size_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "sha256_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "file_name_required": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "rights_status_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "rights_note_required": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "pyq_exam_and_year_required": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "pyq_year_invalid": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "pyq_fields_only_for_official_pyq": status.HTTP_422_UNPROCESSABLE_CONTENT,
    "reason_required": status.HTTP_422_UNPROCESSABLE_CONTENT,
}


def _error(code: str) -> HTTPException:
    return HTTPException(
        _ERROR_STATUS.get(code, status.HTTP_500_INTERNAL_SERVER_ERROR), detail={"code": code}
    )


def _call(rpc: Rpc, function: str, **params: Any) -> Any:
    try:
        return rpc.call(function, params)
    except RuleViolationError as violation:
        raise _error(violation.code) from violation


def _require_content_admin(staff: StaffMember) -> None:
    if not staff.has("content_admin"):
        raise _error("not_authorised")


class SourceFile(BaseModel):
    id: str
    original_name: str
    file_type: FileType
    size_bytes: int
    sha256: str
    rights_status: RightsStatus
    rights_note: str
    pyq_exam_code: str | None
    pyq_year: int | None
    status: FileStatus
    error: str | None
    uploaded_by: str | None
    created_at: datetime
    queued_at: datetime | None


class RightsIn(BaseModel):
    rights_status: RightsStatus
    rights_note: str = Field(min_length=1, max_length=2000)
    pyq_exam_code: str | None = Field(default=None, pattern=r"^[A-Z][A-Z0-9_]{1,31}$")
    pyq_year: int | None = Field(default=None, ge=1980, le=2100)

    @model_validator(mode="after")
    def pyq_fields_match_status(self) -> "RightsIn":
        has_pyq = self.pyq_exam_code is not None and self.pyq_year is not None
        if self.rights_status == "official_pyq" and not has_pyq:
            raise ValueError("official_pyq needs pyq_exam_code and pyq_year")
        if self.rights_status != "official_pyq" and (
            self.pyq_exam_code is not None or self.pyq_year is not None
        ):
            raise ValueError("pyq_exam_code and pyq_year are only for official_pyq")
        return self


class NewFileIn(RightsIn):
    original_name: str = Field(min_length=1, max_length=255)
    file_type: FileType
    size_bytes: int = Field(ge=1, le=MAX_FILE_BYTES)
    sha256: str = Field(pattern=r"^[0-9a-fA-F]{64}$")

    @model_validator(mode="after")
    def extension_matches_type(self) -> "NewFileIn":
        if not self.original_name.lower().endswith(f".{self.file_type}"):
            raise ValueError("original_name must end with the file type's extension")
        return self


class NewFileOut(BaseModel):
    file: SourceFile
    upload_url: str


class RightsChangeIn(RightsIn):
    reason: str = Field(min_length=1, max_length=2000)


def _get(rpc: Rpc, staff: StaffMember, file_id: str) -> SourceFile:
    raw = _call(rpc, "get_source_file", p_actor_id=staff.user_id, p_file_id=file_id)
    return SourceFile.model_validate(raw)


@router.get("/files")
def list_files(
    staff: Staff,
    rpc: RpcDep,
    file_status: Annotated[FileStatus | None, Query(alias="status")] = None,
    rights_status: RightsStatus | None = None,
) -> list[SourceFile]:
    raw = _call(
        rpc,
        "list_source_files",
        p_actor_id=staff.user_id,
        p_status=file_status,
        p_rights_status=rights_status,
    )
    return [SourceFile.model_validate(item) for item in raw]


@router.post("/files", status_code=status.HTTP_201_CREATED)
def create_file(body: NewFileIn, staff: Staff, rpc: RpcDep, storage: StorageDep) -> NewFileOut:
    _require_content_admin(staff)
    row = _call(
        rpc,
        "create_source_file",
        p_actor_id=staff.user_id,
        p_original_name=body.original_name,
        p_file_type=body.file_type,
        p_size_bytes=body.size_bytes,
        p_sha256=body.sha256.lower(),
        p_rights_status=body.rights_status,
        p_rights_note=body.rights_note,
        p_pyq_exam_code=body.pyq_exam_code,
        p_pyq_year=body.pyq_year,
    )
    upload_url = storage.create_signed_upload_url(SOURCE_FILES_BUCKET, row["storage_path"])
    return NewFileOut(file=_get(rpc, staff, row["id"]), upload_url=upload_url)


@router.post("/files/{file_id}/complete")
def complete_upload(file_id: str, staff: Staff, rpc: RpcDep) -> SourceFile:
    _require_content_admin(staff)
    _call(rpc, "complete_source_file_upload", p_actor_id=staff.user_id, p_file_id=file_id)
    return _get(rpc, staff, file_id)


@router.patch("/files/{file_id}/rights")
def change_rights(file_id: str, body: RightsChangeIn, staff: Staff, rpc: RpcDep) -> SourceFile:
    _require_content_admin(staff)
    _call(
        rpc,
        "set_source_file_rights",
        p_actor_id=staff.user_id,
        p_file_id=file_id,
        p_rights_status=body.rights_status,
        p_rights_note=body.rights_note,
        p_reason=body.reason,
        p_pyq_exam_code=body.pyq_exam_code,
        p_pyq_year=body.pyq_year,
    )
    return _get(rpc, staff, file_id)
