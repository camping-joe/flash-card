from fastapi import Request
from fastapi.responses import JSONResponse

class AppException(Exception):
    def __init__(self, code: int, message: str):
        self.code = code
        self.message = message

class NotFoundException(AppException):
    def __init__(self, message: str = "Resource not found"):
        super().__init__(404, message)

class UnauthorizedException(AppException):
    def __init__(self, message: str = "Unauthorized"):
        super().__init__(401, message)

class BadRequestException(AppException):
    def __init__(self, message: str = "Bad request"):
        super().__init__(400, message)

async def app_exception_handler(request: Request, exc: AppException) -> JSONResponse:
    return JSONResponse(
        status_code=200,
        content={"code": exc.code, "message": exc.message, "data": None}
    )

async def generic_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=200,
        content={"code": 500, "message": "Internal server error", "data": None}
    )
