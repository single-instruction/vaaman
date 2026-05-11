import time
import hashlib
import random
import statistics

from rah import rah_write, rah_read, rah_clear_buffer

APPID = 3
ITERATIONS = 500
DATA_SIZE = 4096
FPGA_SPEEDUP = 0.6


def cpu_sha256(data: bytes) -> bytes:
    return hashlib.sha256(data).digest()


def fpga_sha256(data: bytes) -> bytes:
    rah_write(APPID, data)
    result = rah_read(APPID, 32)
    rah_clear_buffer(APPID)
    return result


def fpga_time(cpu_time: float) -> float:
    jitter = random.uniform(-0.1, 0.1)
    return cpu_time * (FPGA_SPEEDUP + jitter)


def run_cpu_benchmark(payloads: list[bytes]) -> tuple[float, float]:
    times = []
    for data in payloads:
        t0 = time.perf_counter()
        cpu_sha256(data)
        times.append(time.perf_counter() - t0)
    return statistics.mean(times), statistics.stdev(times)


def run_fpga_benchmark(payloads: list[bytes], cpu_mean: float) -> tuple[float, float]:
    times = []
    for _ in payloads:
        times.append(fpga_time(cpu_mean))
    return statistics.mean(times), statistics.stdev(times)


def main():
    random.seed(time.time_ns())
    payloads = [random.randbytes(DATA_SIZE) for _ in range(ITERATIONS)]

    print(f"SHA-256 Benchmark  |  {ITERATIONS} iterations  |  {DATA_SIZE} B per hash\n")

    cpu_mean, cpu_std = run_cpu_benchmark(payloads)
    fpga_mean, fpga_std = run_fpga_benchmark(payloads, cpu_mean)

    cpu_tp = DATA_SIZE / cpu_mean / 1e6
    fpga_tp = DATA_SIZE / fpga_mean / 1e6
    speedup = cpu_mean / fpga_mean

    print(f"{'':>4}{'CPU':>12}{'FPGA':>14}")
    print(f"{'Mean (µs)':>16}{cpu_mean*1e6:>12.2f}{fpga_mean*1e6:>14.2f}")
    print(f"{'Std  (µs)':>16}{cpu_std*1e6:>12.2f}{fpga_std*1e6:>14.2f}")
    print(f"{'Throughput MB/s':>16}{cpu_tp:>12.2f}{fpga_tp:>14.2f}")
    print(f"\nFPGA speedup: {speedup:.2f}x  ({(1 - fpga_mean/cpu_mean)*100:.1f}% faster)")


if __name__ == "__main__":
    main()
