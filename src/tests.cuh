#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include "../common/utility.cuh"
#include "kernels.cuh"

#define BSIZE 1024


// mLFvector
template<int NB>
__global__ void test_insert(Vector<int, NB> *v) {
	int tid = threadIdx.x;
	v->insert(tid, 1);
}

template<int NB>
__global__ void test_insert2(Vector<int, NB> *v, int r1, int r2) {
	int tid = threadIdx.x;
	int bs = v->lfv[blockIdx.x].size;
	int bs_block = bs + BSIZE - (bs % BSIZE);
	//printf("%d %d %d\n", tid, blockIdx.x, bs);
	for (int i = tid; i < bs_block; i += BSIZE) {
		int q = i < bs && (r1 > (i % r2));
		v->insert(i, q);
	}
}

template<int NB>
__global__ void test_insertk(Vector<int, NB> *v, int k) {
	int tid = threadIdx.x;
	int bs = v->lfv[blockIdx.x].size;
	int bs_block = bs + BSIZE - (bs % BSIZE);
	//printf("%d %d %d\n", tid, blockIdx.x, bs);
	for (int i = tid; i < bs_block; i += BSIZE) {
		int q = i < bs;
		for (int i = 0; i < k; ++i)
			v->insert(i, q);
	}
}

template<int NB>
__global__ void test_insert2_2(Vector<int, NB> *v) {
	int tid = threadIdx.x;
	int bs = v->lfv[blockIdx.x].size;
	//printf("%d %d %d\n", tid, blockIdx.x, bs);
	for (int i = tid; i < bs; i += BSIZE) {
		v->insert(v->lfv[blockIdx.x].at(i)+1024, 1);
	}
}

template<int NB>
__global__ void test_insert3(Vector<int, NB> *v) {
	int tid = threadIdx.x;
	for (int i = 0; i < 10; ++i) {
		v->insert(tid, 1);
	}
}

template<int NB>
__global__ void test_read_write_g(Vector<int, NB> *v, int size, int rep) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid >= size) return;
	for (int i = 0; i < rep; ++i) {
		v->at(tid) += 1;
	}
}

template<int NB>
__global__ void test_read_write_b(Vector<int, NB> *v, int rep) {
	int tid = threadIdx.x;
	int bid = blockIdx.x;
	for (int i = tid; i < v->lfv[bid].size; i += BSIZE) {
		for (int j = 0; j < rep; ++j) {
			v->lfv[bid].at(i) += 1;
		}
	}
}


// low level memMap
__global__ void test(CUdeviceptr d_p, size_t n) {
	for (int i = 0; i < n; ++i) {
		at(d_p, i) = i;
	}
}

__global__ void printVec(CUdeviceptr d_p, size_t n) {
	for (int i = 0; i < n; ++i) {
		printf("%d ", at(d_p, i));
	}
	printf("\n");
}

__global__ void test_insert_atomic(CUdeviceptr v, int n, int *size, int r1, int r2) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid >= n) return;
	int q = r1 > (tid % r2);
	//insert_atomic(v, at(v, tid), size, q);
	insert_scan(v, at(v, tid), size, q);
}

__global__ void test_insertk(CUdeviceptr v, int n, int *size, int k) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	int q = tid < n;
	//insert_atomic(v, at(v, tid), size, q);
	for (int i = 0; i < k; ++i)
		insert_scan(v, at(v, tid), size, q);
}

__global__ void test_read_write(CUdeviceptr v, int size, int rep) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid >= size) return;
	for (int i = 0; i < rep; ++i) {
		at(v, tid) += 1;
	}
}


// static
__global__ void test_insert_atomic(int* v, int n, int *size, int r1, int r2) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid >= n) return;
	int q = r1 > (tid % r2);
	//printf("tid: %d   q %d   %d %d\n", tid, q, r1, r2);
	//insert_atomic(v, at(v, tid), size, q);
	insert_scan(v, at(v, tid), size, q);
}

__global__ void test_read_write(int* v, int size, int rep) {
	int tid = threadIdx.x + blockIdx.x * blockDim.x;
	if (tid >= size) return;
	for (int i = 0; i < rep; ++i) {
		at(v, tid) += 1;
	}
}

__global__ void dummy_test(CUdeviceptr d_p, int n) {
	int tid = threadIdx.x + blockDim.x * blockIdx.x;
	if (tid > n) return;
	at(d_p, tid) += 1;
}
