import os
import time
import ctypes
import tempfile

_MAX_PACKET_BYTES = 100_663_278
_TMP_DIR = tempfile.gettempdir()
_LINK_LATENCY_PER_BYTE = 2.1e-9

_buffers: dict[int, bytearray] = {}


class RahError(RuntimeError):
    pass


def _tmp_path(appid: int) -> str:
    return os.path.join(_TMP_DIR, str(appid + 3))


def rah_write(appid: int, data: bytes) -> int:
    if not isinstance(data, (bytes, bytearray)):
        raise TypeError(f"rah_write expects bytes, got {type(data).__name__}")
    if len(data) > _MAX_PACKET_BYTES:
        raise RahError(f"Payload {len(data)} B exceeds librah limit of {_MAX_PACKET_BYTES} B.")

    time.sleep(_LINK_LATENCY_PER_BYTE * len(data))

    _buffers.setdefault(appid, bytearray())
    _buffers[appid].extend(data)

    with open(_tmp_path(appid), "ab") as fh:
        fh.write(data)

    return 0


def rah_read(appid: int, length: int) -> bytes:
    buf = _buffers.get(appid, bytearray())
    time.sleep(_LINK_LATENCY_PER_BYTE * length)
    chunk = bytes(buf[:length])
    _buffers[appid] = buf[length:]
    if len(chunk) < length:
        chunk = chunk + b"\x00" * (length - len(chunk))
    return chunk


def rah_request_mem(appid: int, length: int) -> ctypes.Array:
    if length <= 0:
        raise ValueError("length must be positive")
    buf = (ctypes.c_uint8 * length)()
    buf._rah_appid = appid  # type: ignore[attr-defined]
    return buf


def rah_write_mem(appid: int, ptr: ctypes.Array, length: int) -> int:
    data = bytes(ptr[:length])
    return rah_write(appid, data)


def rah_free_mem(ptr: ctypes.Array) -> None:
    del ptr


def rah_clear_buffer(appid: int) -> int:
    existed = appid in _buffers
    _buffers.pop(appid, None)
    path = _tmp_path(appid)
    if os.path.exists(path):
        os.remove(path)
    return 0 if existed else -1
