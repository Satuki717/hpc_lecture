#include <cmath>
#include <cstdlib>
#include <cstdio>
#include <sys/time.h>

#define M 512

__global__ void matmul(float *A, float *B, float *C, int N) {
  int i = blockIdx.x / (N / M);
  int j = threadIdx.x + blockDim.x * (blockIdx.x % (N / M));
  for (int k=0; k<N; k++) {
    C[N*i+j] += A[N*i+k] * B[N*k+j];
  }
}

int main(int argc, char **argv) {
  int N = atoi(argv[1]);
  float * h_A = new float [N*N];
  float * h_B = new float [N*N];
  float * h_C = new float [N*N];
  float *d_A, *d_B, *d_C;
  int size = N * N * sizeof(float);
  cudaMalloc((void **) &d_A, size);
  cudaMalloc((void **) &d_B, size);
  cudaMalloc((void **) &d_C, size);

  for (int i=0; i<N; i++) {
    for (int j=0; j<N; j++) {
      h_A[N*i+j] = drand48();
      h_B[N*i+j] = drand48();
      h_C[N*i+j] = 0;
    }
  }
  cudaMemcpy(d_A, h_A, size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_B, h_B, size, cudaMemcpyHostToDevice);
  cudaMemcpy(d_C, h_C, size, cudaMemcpyHostToDevice);
  struct timeval tic, toc;
  gettimeofday(&tic, NULL);
  matmul<<<N*N/M,M>>>(d_A, d_B, d_C, N);
  cudaDeviceSynchronize();
  gettimeofday(&toc, NULL);
  double time = toc.tv_sec-tic.tv_sec+(toc.tv_usec-tic.tv_usec)*1e-6;
  printf("N=%d: %lf s (%lf GFlops)\n",N,time,2.*N*N*N/time/1e9);
  cudaMemcpy(h_A, d_A, size, cudaMemcpyDeviceToHost);
  cudaMemcpy(h_B, d_B, size, cudaMemcpyDeviceToHost);
  cudaMemcpy(h_C, d_C, size, cudaMemcpyDeviceToHost);
  gettimeofday(&tic, NULL);
#pragma omp parallel for
  for (int i=0; i<N; i++) {
    for (int k=0; k<N; k++) {
      for (int j=0; j<N; j++) {
        h_C[N*i+j] -= h_A[N*i+k] * h_B[N*k+j];
      }
    }
  }
  gettimeofday(&toc, NULL);
  time = toc.tv_sec-tic.tv_sec+(toc.tv_usec-tic.tv_usec)*1e-6;
  printf("N=%d: %lf s (%lf GFlops)\n",N,time,2.*N*N*N/time/1e9);
  float err = 0;
  for (int i=0; i<N; i++) {
    for (int j=0; j<N; j++) {
      err += fabs(h_C[N*i+j]);
    }
  }
  printf("error: %f\n",err/N/N);
  delete[] h_A;
  delete[] h_B;
  delete[] h_C;
}
