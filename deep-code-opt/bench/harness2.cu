// harness2: cenarios do uso real que passam pelo modulo nvidia (RM/GSP, UVM, fences, DMA, NVENC).
// Por cenario: N chunks; em cada chunk mede wall/op (us) e ciclos de KERNEL/op (perf_event_open, cpu_core, exclude_user).
// Uso: harness2 <chunks> <escala>   Saida: JSON {cenario: {"wall":[...], "kcyc":[...]}}
#include <cuda.h>
#include <cuda_runtime.h>
#include <dlfcn.h>
#include <linux/perf_event.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <unistd.h>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <functional>
#include <string>
#include <vector>
#include "ffnvcodec/nvEncodeAPI.h"

#define CK(x) do { cudaError_t e = (x); if (e != cudaSuccess) { fprintf(stderr, "%s:%d %s\n", __FILE__, __LINE__, cudaGetErrorString(e)); exit(2); } } while (0)
#define NK(x) do { NVENCSTATUS s = (x); if (s != NV_ENC_SUCCESS) { fprintf(stderr, "%s:%d nvenc %d\n", __FILE__, __LINE__, (int)s); exit(3); } } while (0)

__global__ void empty_kernel() {}

static int g_perf_fd = -1;
static long long kcycles() { long long v = 0; if (read(g_perf_fd, &v, sizeof v) != sizeof v) exit(4); return v; }
static double now_us() { return std::chrono::duration<double, std::micro>(std::chrono::steady_clock::now().time_since_epoch()).count(); }

static void open_kernel_cycle_counter() {
    FILE *f = fopen("/sys/bus/event_source/devices/cpu_core/type", "r");
    int type = PERF_TYPE_HARDWARE; if (f) { if (fscanf(f, "%d", &type) != 1) type = PERF_TYPE_HARDWARE; fclose(f); }
    perf_event_attr a; memset(&a, 0, sizeof a);
    a.size = sizeof a; a.type = PERF_TYPE_HARDWARE; a.config = PERF_COUNT_HW_CPU_CYCLES | ((unsigned long long)type << 32); a.exclude_user = 1; a.exclude_hv = 1;
    g_perf_fd = syscall(SYS_perf_event_open, &a, 0, -1, -1, 0);
    if (g_perf_fd < 0) { perror("perf_event_open"); exit(4); }
}

static bool g_first = true;
static void scenario(const char *name, int chunks, int per, const std::function<void()> &op) {
    for (int i = 0; i < per; i++) op();  // warmup
    std::vector<double> wall, kc;
    for (int c = 0; c < chunks; c++) {
        long long k0 = kcycles(); double t0 = now_us();
        for (int i = 0; i < per; i++) op();
        double t1 = now_us(); long long k1 = kcycles();
        wall.push_back((t1 - t0) / per); kc.push_back(double(k1 - k0) / per);
    }
    printf("%s\"%s\":{\"wall\":[", g_first ? "" : ",", name); g_first = false;
    for (size_t i = 0; i < wall.size(); i++) printf("%s%.4f", i ? "," : "", wall[i]);
    printf("],\"kcyc\":[");
    for (size_t i = 0; i < kc.size(); i++) printf("%s%.1f", i ? "," : "", kc[i]);
    printf("]}");
    fflush(stdout);
}

struct Nvenc {
    NV_ENCODE_API_FUNCTION_LIST f{};
    void *enc = nullptr; NV_ENC_REGISTERED_PTR reg = nullptr; NV_ENC_OUTPUT_PTR bs = nullptr;
    CUdeviceptr frame = 0; size_t pitch = 0;
    static const int W = 1920, H = 1080;
    void init(CUcontext ctx) {
        void *lib = dlopen("libnvidia-encode.so.1", RTLD_NOW); if (!lib) { fprintf(stderr, "dlopen nvenc\n"); exit(3); }
        auto create = (NVENCSTATUS(*)(NV_ENCODE_API_FUNCTION_LIST *))dlsym(lib, "NvEncodeAPICreateInstance");
        f.version = NV_ENCODE_API_FUNCTION_LIST_VER; NK(create(&f));
        NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS op{}; op.version = NV_ENC_OPEN_ENCODE_SESSION_EX_PARAMS_VER;
        op.deviceType = NV_ENC_DEVICE_TYPE_CUDA; op.device = ctx; op.apiVersion = NVENCAPI_VERSION;
        NK(f.nvEncOpenEncodeSessionEx(&op, &enc));
        NV_ENC_PRESET_CONFIG pc{}; pc.version = NV_ENC_PRESET_CONFIG_VER; pc.presetCfg.version = NV_ENC_CONFIG_VER;
        NK(f.nvEncGetEncodePresetConfigEx(enc, NV_ENC_CODEC_HEVC_GUID, NV_ENC_PRESET_P1_GUID, NV_ENC_TUNING_INFO_ULTRA_LOW_LATENCY, &pc));
        NV_ENC_CONFIG cfg = pc.presetCfg; cfg.gopLength = NVENC_INFINITE_GOPLENGTH; cfg.frameIntervalP = 1;
        NV_ENC_INITIALIZE_PARAMS ip{}; ip.version = NV_ENC_INITIALIZE_PARAMS_VER; ip.encodeGUID = NV_ENC_CODEC_HEVC_GUID;
        ip.presetGUID = NV_ENC_PRESET_P1_GUID; ip.tuningInfo = NV_ENC_TUNING_INFO_ULTRA_LOW_LATENCY;
        ip.encodeWidth = ip.darWidth = W; ip.encodeHeight = ip.darHeight = H; ip.frameRateNum = 120; ip.frameRateDen = 1;
        ip.enablePTD = 1; ip.encodeConfig = &cfg;
        NK(f.nvEncInitializeEncoder(enc, &ip));
        if (cuMemAllocPitch(&frame, &pitch, W, H * 3 / 2, 16) != CUDA_SUCCESS) exit(3);
        cuMemsetD8(frame, 0x80, pitch * H * 3 / 2);
        NV_ENC_REGISTER_RESOURCE rr{}; rr.version = NV_ENC_REGISTER_RESOURCE_VER; rr.resourceType = NV_ENC_INPUT_RESOURCE_TYPE_CUDADEVICEPTR;
        rr.resourceToRegister = (void *)frame; rr.width = W; rr.height = H; rr.pitch = (uint32_t)pitch; rr.bufferFormat = NV_ENC_BUFFER_FORMAT_NV12;
        NK(f.nvEncRegisterResource(enc, &rr)); reg = rr.registeredResource;
        NV_ENC_CREATE_BITSTREAM_BUFFER cb{}; cb.version = NV_ENC_CREATE_BITSTREAM_BUFFER_VER; NK(f.nvEncCreateBitstreamBuffer(enc, &cb)); bs = cb.bitstreamBuffer;
    }
    void encode_one(unsigned frame_idx) {
        NV_ENC_MAP_INPUT_RESOURCE mp{}; mp.version = NV_ENC_MAP_INPUT_RESOURCE_VER; mp.registeredResource = reg;
        NK(f.nvEncMapInputResource(enc, &mp));
        NV_ENC_PIC_PARAMS pp{}; pp.version = NV_ENC_PIC_PARAMS_VER; pp.inputBuffer = mp.mappedResource; pp.bufferFmt = NV_ENC_BUFFER_FORMAT_NV12;
        pp.inputWidth = W; pp.inputHeight = H; pp.inputPitch = (uint32_t)pitch; pp.outputBitstream = bs; pp.pictureStruct = NV_ENC_PIC_STRUCT_FRAME; pp.inputTimeStamp = frame_idx;
        NK(f.nvEncEncodePicture(enc, &pp));
        NV_ENC_LOCK_BITSTREAM lb{}; lb.version = NV_ENC_LOCK_BITSTREAM_VER; lb.outputBitstream = bs;
        NK(f.nvEncLockBitstream(enc, &lb)); NK(f.nvEncUnlockBitstream(enc, bs));
        NK(f.nvEncUnmapInputResource(enc, mp.mappedResource));
    }
};

int main(int argc, char **argv) {
    int chunks = argc > 1 ? atoi(argv[1]) : 20; double s = argc > 2 ? atof(argv[2]) : 1.0;
    auto n = [&](int base) { int v = int(base * s); return v > 0 ? v : 1; };
    open_kernel_cycle_counter();
    CK(cudaSetDevice(0)); CK(cudaFree(0));
    cudaStream_t st; CK(cudaStreamCreate(&st));
    cudaEvent_t ev_spin, ev_block; CK(cudaEventCreate(&ev_spin)); CK(cudaEventCreateWithFlags(&ev_block, cudaEventBlockingSync));
    void *dev, *pinned; CK(cudaMalloc(&dev, 1 << 20)); CK(cudaMallocHost(&pinned, 1 << 20));
    void *managed; CK(cudaMallocManaged(&managed, 2 << 20)); memset(managed, 1, 2 << 20);
    void *hostbuf = mmap(nullptr, 1 << 20, PROT_READ | PROT_WRITE, MAP_PRIVATE | MAP_ANONYMOUS | MAP_POPULATE, -1, 0); madvise(hostbuf, 1 << 20, MADV_NOHUGEPAGE); memset(hostbuf, 2, 1 << 20);  // sem THP: custo de pin deterministico
    cudaMemLocation gpu{cudaMemLocationTypeDevice, 0}, cpu{cudaMemLocationTypeHost, 0};
    CUcontext ctx; cuCtxGetCurrent(&ctx);
    Nvenc nv; nv.init(ctx); unsigned fi = 0;

    printf("{");
    scenario("submit_spin", chunks, n(1500), [&] { empty_kernel<<<1, 1, 0, st>>>(); CK(cudaEventRecord(ev_spin, st)); CK(cudaEventSynchronize(ev_spin)); });
    scenario("fence_block", chunks, n(200), [&] { empty_kernel<<<1, 1, 0, st>>>(); CK(cudaEventRecord(ev_block, st)); CK(cudaEventSynchronize(ev_block)); });
    scenario("alloc2m", chunks, n(60), [&] { void *p; CK(cudaMalloc(&p, 2 << 20)); CK(cudaFree(p)); });
    scenario("h2d64k", chunks, n(600), [&] { CK(cudaMemcpyAsync(dev, pinned, 65536, cudaMemcpyHostToDevice, st)); CK(cudaStreamSynchronize(st)); });
    scenario("hostreg1m", chunks, n(40), [&] { CK(cudaHostRegister(hostbuf, 1 << 20, cudaHostRegisterDefault)); CK(cudaHostUnregister(hostbuf)); });
    scenario("uvm_prefetch2m", chunks, n(30), [&] { CK(cudaMemPrefetchAsync(managed, 2 << 20, gpu, 0, st)); CK(cudaMemPrefetchAsync(managed, 2 << 20, cpu, 0, st)); CK(cudaStreamSynchronize(st)); });
    scenario("ctx_create", chunks < 10 ? chunks : 10, 1, [&] { CUcontext c2; if (cuCtxCreate(&c2, nullptr, 0, 0) != CUDA_SUCCESS) exit(5); cuCtxDestroy(c2); cuCtxSetCurrent(ctx); });
    scenario("nvenc1080p", chunks, n(40), [&] { nv.encode_one(fi++); });
    printf("}\n"); fflush(stdout);
    _exit(0);  // teardown do CUDA com sessao NVENC aberta trava; o kernel limpa tudo no exit
}
