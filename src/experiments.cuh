#include <cuda.h>
#include <stdio.h>
#include <stdlib.h>
#include "../common/utility.cuh"
#include "tests.cuh"

#define BSIZE 1024
#define REP 10
#define RW_REP 30


// test NB
template<int NB>
void optimal_NB(Vector<int, NB> *v, int size, int ratio) {
	int *ds;
	gpuErrCheck( cudaMalloc(&ds, sizeof(int)) );
	//fprintf(stderr, "NB  %d \n", NB); 

	createLFVector<<<1,1>>>(v); kernelCallCheck();
	initVec<<<NB,BSIZE>>>(v, size); kernelCallCheck();

	cudaEvent_t start, stop;
	start_clock(start, stop);

	growVec<<<1,NB>>>(v, 2*size);
	test_insert2<<<NB, BSIZE>>>(v); kernelCallCheck();
	cudaDeviceSynchronize();

	float time = stop_clock(start, stop);
	printf("%d,%d,%f,", size, NB, time);


	//printVec<<<1,1>>>(v);
	get_size<<<1,1>>>(ds, v);
	cudaMemcpy(&size, ds, sizeof(int), cudaMemcpyDeviceToHost);
	//fprintf(stderr, "size  %d \n", size); 
	start_clock(start, stop);
	test_read_write_g<<<gridSize(size, BSIZE), BSIZE>>>(v, size, RW_REP); kernelCallCheck();
	cudaDeviceSynchronize();
	time = stop_clock(start, stop);
	printf("%f,", time);

	start_clock(start, stop);
	test_read_write_b<<<NB, BSIZE>>>(v, RW_REP); kernelCallCheck();
	cudaDeviceSynchronize();
	time = stop_clock(start, stop);
	printf("%f\n", time);
}

// growth
template<int NB>
void growth_experiment(Vector<int, NB> *v, int size, int ratio) {
	int *ds;
	gpuErrCheck( cudaMalloc(&ds, sizeof(int)) );

	int rep = REP;
	int size_exp = 29 - rep;
	size = 1 << size_exp;
	int o_size = size;
	createLFVector<<<1,1>>>(v); kernelCallCheck();
	initVec<<<NB,BSIZE>>>(v, size); kernelCallCheck();
	float results[rep];

	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;
		start_clock(start, stop);

		growVec<<<1,NB>>>(v, 2*size); kernelCallCheck();
		cudaDeviceSynchronize();

		results[i] = stop_clock(start, stop);
	}

	printf("mlfv%d,grow,%d,%d,", NB, o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}

void growth_experiment(CUcontext ctx, int size, int ratio) {
	int rep = REP;
	int o_size = size;
	int *ds;
	cudaMalloc(&ds, sizeof(int));
	cudaMemcpy(ds, &size, sizeof(int), cudaMemcpyHostToDevice);

	VectorMemMap a = VectorMemMap(ctx);

	a.grow(size*sizeof(int));
	initVec<<<gridSize(size, 1024), 1024>>>(a.getPointer(), size); kernelCallCheck();

	float results[rep];
	
	for (int i = 0; i < rep; ++i) {

		// grow
		cudaEvent_t start, stop;
		start_clock(start, stop);
		a.grow(size*2*sizeof(int)); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
	}

	// print results
	printf("memMap,grow,%d,%d,", o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}


// insertion
template<int NB>
void insertion_experiment(Vector<int, NB> *v, int size, int ratio) {
	int *ds;
	gpuErrCheck( cudaMalloc(&ds, sizeof(int)) );

	int rep = REP;
	int size_exp = 29 - rep;
	size = 1 << size_exp;
	int o_size = size;
	createLFVector<<<1,1>>>(v); kernelCallCheck();
	initVec<<<NB,BSIZE>>>(v, size); kernelCallCheck();
	//printVec<<<1,1>>>(v); kernelCallCheck();
	float results[rep];

	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;

		// grow
		growVec<<<1,NB>>>(v, 2*size);
		cudaDeviceSynchronize();

		// insertion
		start_clock(start, stop);
		test_insert2<<<NB, BSIZE>>>(v); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
	}
	
	// print results
	printf("mlfv%d,in,%d,%d,", NB, o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}

void insertion_experiment(CUcontext ctx, int size, int ratio) {
	int rep = REP;
	int o_size = size;
	int *ds;
	cudaMalloc(&ds, sizeof(int));
	cudaMemcpy(ds, &size, sizeof(int), cudaMemcpyHostToDevice);

	VectorMemMap a = VectorMemMap(ctx);

	a.grow(size*sizeof(int));
	initVec<<<gridSize(size, 1024), 1024>>>(a.getPointer(), size); kernelCallCheck();

	float results[rep];
	
	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;
		// grow
		a.grow(size*2*sizeof(int));
		cudaDeviceSynchronize();
		
		// insertion
		start_clock(start, stop);
		test_insert_atomic<<<gridSize(size, 1024), 1024>>>(a.getPointer(), size, ds); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
		cudaMemcpy(&size, ds, sizeof(int), cudaMemcpyDeviceToHost);
	}

	// print results
	printf("memMap,in,%d,%d,", o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}


void insertion_experiment(int size, int ratio) {
	int rep = REP;
	int o_size = size;

	int *a, *ha;
	int *dsize;
	ha = new int[size];
	for (int i = 0; i < size; ++i) {
		ha[i] = i;
	}
	gpuErrCheck( cudaMalloc(&a, 2*size*2^rep*sizeof(int)) );
	gpuErrCheck( cudaMalloc(&dsize, sizeof(int)) );
	gpuErrCheck( cudaMemcpy(a, ha, size*sizeof(int), cudaMemcpyHostToDevice)) ;
	gpuErrCheck( cudaMemcpy(dsize, &size, sizeof(int), cudaMemcpyHostToDevice) );


	float results[rep];

	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;
		start_clock(start, stop);
		test_insert_atomic<<<gridSize(size, BSIZE), BSIZE>>>(a, size, dsize); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
		cudaMemcpy(&size, dsize, sizeof(int), cudaMemcpyDeviceToHost);

	}

	// print results
	printf("static,in,%d,%d,", o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}



// read - write
template<int NB>
void rw_experiment(Vector<int, NB> *v, int size, int ratio, int rw_mode) {
	int *ds;
	gpuErrCheck( cudaMalloc(&ds, sizeof(int)) );

	int rep = REP;
	int size_exp = 29 - rep;
	size = 1 << size_exp;
	int rw_rep = RW_REP;
	int o_size = size;
	createLFVector<<<1,1>>>(v); kernelCallCheck();
	initVec<<<NB,BSIZE>>>(v, size); kernelCallCheck();
	//printVec<<<1,1>>>(v); kernelCallCheck();
	float results[rep];

	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;

		// grow
		growVec<<<1,NB>>>(v, 2*size);
		cudaDeviceSynchronize();

		// insertion
		test_insert2<<<NB, BSIZE>>>(v); kernelCallCheck();
		cudaDeviceSynchronize();

		// read/write
		get_size<<<1,1>>>(ds, v);
		cudaMemcpy(&size, ds, sizeof(int), cudaMemcpyDeviceToHost);
		start_clock(start, stop);
		if (rw_mode == 0) {
			test_read_write_g<<<gridSize(size, BSIZE), BSIZE>>>(v, size, rw_rep); kernelCallCheck();
		} else {
			test_read_write_b<<<NB, BSIZE>>>(v, rw_rep); kernelCallCheck();
		}
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
		size *= 2;
	}
	
	// print results
	printf("mlfv%d,rw%d,%d,%d,", NB, rw_rep, o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}

void rw_experiment(CUcontext ctx, int size, int ratio) {
	int rep = REP;
	int rw_rep = RW_REP;
	int o_size = size;
	int *ds;
	cudaMalloc(&ds, sizeof(int));
	cudaMemcpy(ds, &size, sizeof(int), cudaMemcpyHostToDevice);

	VectorMemMap a = VectorMemMap(ctx);

	a.grow(size*sizeof(int));
	initVec<<<gridSize(size, 1024), 1024>>>(a.getPointer(), size); kernelCallCheck();

	float results[rep];
	
	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;
		// grow
		a.grow(size*2*sizeof(int));
		cudaDeviceSynchronize();
		
		// insertion
		test_insert_atomic<<<gridSize(size, 1024), 1024>>>(a.getPointer(), size, ds); kernelCallCheck();
		cudaDeviceSynchronize();
		cudaMemcpy(&size, ds, sizeof(int), cudaMemcpyDeviceToHost);

		// read/write
		CUdeviceptr dp = a.getPointer();
		start_clock(start, stop);
		test_read_write<<<gridSize(size, 1024), 1024>>>(dp, size, rw_rep); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
	}

	printf("memMap,rw%d,%d,%d,", rw_rep, o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}

void rw_experiment(int size, int ratio) {
	int rep = REP;
	int rw_rep = RW_REP;
	int o_size = size;

	int *a, *ha;
	int *dsize;
	ha = new int[size];
	for (int i = 0; i < size; ++i) {
		ha[i] = i;
	}
	gpuErrCheck( cudaMalloc(&a, 2*size*2^rep*sizeof(int)) );
	gpuErrCheck( cudaMalloc(&dsize, sizeof(int)) );
	gpuErrCheck( cudaMemcpy(a, ha, size*sizeof(int), cudaMemcpyHostToDevice)) ;
	gpuErrCheck( cudaMemcpy(dsize, &size, sizeof(int), cudaMemcpyHostToDevice) );


	float results[rep];

	for (int i = 0; i < rep; ++i) {
		cudaEvent_t start, stop;
		test_insert_atomic<<<gridSize(size, BSIZE), BSIZE>>>(a, size, dsize); kernelCallCheck();
		cudaDeviceSynchronize();
		cudaMemcpy(&size, dsize, sizeof(int), cudaMemcpyDeviceToHost);

		// read/write
		start_clock(start, stop);
		test_read_write<<<gridSize(size, 1024), 1024>>>(a, size, rw_rep); kernelCallCheck();
		cudaDeviceSynchronize();
		results[i] = stop_clock(start, stop);
	}

	// print results
	printf("static,rw%d,%d,%d,", rw_rep, o_size, ratio);
	for (int i = 0; i < rep-1; ++i) {
		printf("%f,", results[i]);
	}
	printf("%f\n", results[rep-1]);
}



