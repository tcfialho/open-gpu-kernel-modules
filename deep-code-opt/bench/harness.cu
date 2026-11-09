// Harness driver nvidia: latência de caminho quente do driver (ioctl/fence/DMA). Saída JSON: amostras por cenário (us/op por chunk).
#include <cuda_runtime.h>
#include <cstdio>
#include <cstdlib>
#include <chrono>
#include <vector>
__global__ void empty_kernel() {}
#define CK(x) do{cudaError_t e=(x); if(e!=cudaSuccess){fprintf(stderr,"%s:%d %s\n",__FILE__,__LINE__,cudaGetErrorString(e)); exit(2);}}while(0)
static double now_us(){ return std::chrono::duration<double,std::micro>(std::chrono::steady_clock::now().time_since_epoch()).count(); }
template<class F> static void scenario(const char* name,int chunks,int per,F f,bool last){
  for(int i=0;i<2000;i++) f();
  std::vector<double> s; s.reserve(chunks);
  for(int c=0;c<chunks;c++){ double t0=now_us(); for(int i=0;i<per;i++) f(); s.push_back((now_us()-t0)/per); }
  printf("\"%s\":[",name); for(size_t i=0;i<s.size();i++) printf("%s%.4f",i?",":"",s[i]); printf("]%s",last?"":",");
}
int main(int argc,char**argv){
  int chunks=argc>1?atoi(argv[1]):300, per=argc>2?atoi(argv[2]):500;
  CK(cudaSetDevice(0)); CK(cudaSetDeviceFlags(cudaDeviceScheduleSpin)); cudaStream_t st; CK(cudaStreamCreate(&st));
  cudaEvent_t ev; CK(cudaEventCreate(&ev));
  void *dev,*host; CK(cudaMalloc(&dev,65536)); CK(cudaMallocHost(&host,65536));
  printf("{");
  scenario("submit_sync",chunks,per,[&]{ empty_kernel<<<1,1,0,st>>>(); CK(cudaStreamSynchronize(st)); },false);
  scenario("event_sync",chunks,per,[&]{ CK(cudaEventRecord(ev,st)); CK(cudaEventSynchronize(ev)); },false);
  scenario("dma4k",chunks,per,[&]{ CK(cudaMemcpyAsync(host,dev,4096,cudaMemcpyDeviceToHost,st)); CK(cudaStreamSynchronize(st)); },false);
  scenario("dma64k",chunks,per,[&]{ CK(cudaMemcpyAsync(host,dev,65536,cudaMemcpyDeviceToHost,st)); CK(cudaStreamSynchronize(st)); },false);
  int p2=per/10>0?per/10:1;
  scenario("malloc_free",chunks,p2,[&]{ void*q; CK(cudaMalloc(&q,4096)); CK(cudaFree(q)); },false);
  scenario("stream_cd",chunks,p2,[&]{ cudaStream_t s2; CK(cudaStreamCreate(&s2)); CK(cudaStreamDestroy(s2)); },false);
  scenario("event_cd",chunks,per,[&]{ cudaEvent_t e2; CK(cudaEventCreate(&e2)); CK(cudaEventDestroy(e2)); },false);
  scenario("managed_fault",chunks,p2/2>0?p2/2:1,[&]{ char*m; CK(cudaMallocManaged(&m,65536)); for(int o=0;o<65536;o+=4096) m[o]=1; CK(cudaFree(m)); },true);
  printf("}\n"); return 0;
}
