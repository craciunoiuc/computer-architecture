#include <iostream>
#include <limits.h>
#include <stdlib.h>
#include <ctime>
#include <sstream>
#include <string>

#include "./gpu_hashtable.hpp"

/*
 * The operations in each for iteration are atomic,
 * so there won't be any concurrency problems.
 * After the Compare-And-Set operation there will be 3 cases:
 * 1. The returned value (old value) is 0 -> the value will be added
 * 2. The returned value is the same as the key -> the value will be replaced
 * 3. The returned value is not the same as the key -> the entry is skipped
 */
__global__ void insert_entry(int *keys, int *values, int nr_keys,
							hashtable_t hashtable) {
	unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
	CHECK_ERROR_NORET(idx >= nr_keys);
	CHECK_ERROR_NORET(keys[idx] <= 0 || values[idx] <= 0);
	
	// Save the key that needs to be added and calculate its hash
	int key_to_add = keys[idx];
	int hash = HASH_INT(key_to_add, hashtable.max_elements);

	// Iterate through the table until an empty spot is
	// found in [hash, max_elements)
	for (int i = hash; i < hashtable.max_elements; ++i) {
		int key_before = atomicCAS(&hashtable.entries[i].key,
								KEY_INVALID, key_to_add);
		if (key_before == KEY_INVALID || key_before == key_to_add) {
			atomicExch(&hashtable.entries[i].value, values[idx]);
			return;
		}
	}

	// Iterate through the table in a similar fashion,
	// until an empty spot is found in [0, hash)
	for (int i = 0; i < hash; ++i) {
		int key_before = atomicCAS(&hashtable.entries[i].key,
									KEY_INVALID, key_to_add);
		if (key_before == KEY_INVALID || key_before == key_to_add) {
			atomicExch(&hashtable.entries[i].value, values[idx]);
			return;
		}
	}

	// The end should not be reached (the function gets here if table is full)
}

/*
 * The function (for each thread) iterates through the table and writes the
 * first value that matches the key into the values vector
 */
__global__ void get_entry(int *keys, int *values, int nr_keys,
							hashtable_t hashtable) {
	unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;
	CHECK_ERROR_NORET(idx >= nr_keys);
	int key_to_find = keys[idx];
	int hash = HASH_INT(key_to_find, hashtable.max_elements);

	for (int i = hash; i < hashtable.max_elements; ++i) {
		if (hashtable.entries[i].key == key_to_find) {
			atomicExch(&values[idx], hashtable.entries[i].value);
			return;
		}
	}
	
	for (int i = 0; i < hash; ++i) {
		if (hashtable.entries[i].key == key_to_find) {
			atomicExch(&values[idx], hashtable.entries[i].value);
			return;
		}
	}

	// Should get here only if the value is not found
	values[idx] = -1;
}

/*
 * The function works the same as the insert function. The function is called
 * for each element of the old hashtable and each thread inserts its element
 * in the hashtable in a similar fashion as insert_entry.
 */
__global__ void reshape_entry(entry_t *old_entries, int old_max_elements,
							  entry_t *new_entries, int new_max_elements) {
	unsigned int idx = blockIdx.x * blockDim.x + threadIdx.x;				  
	CHECK_ERROR_NORET(idx >= old_max_elements);
	CHECK_ERROR_NORET(old_entries[idx].key == KEY_INVALID);
	
	int key_to_add = old_entries[idx].key;
	int hash = HASH_INT(key_to_add, new_max_elements);

	// Iterate through the table until an empty spot is
	// found in [hash, max_elements)
	for (int i = hash; i < new_max_elements; ++i) {
		int key_before = atomicCAS(&new_entries[i].key,
								KEY_INVALID, key_to_add);
		if (key_before == KEY_INVALID) {
			atomicExch(&new_entries[i].value, old_entries[idx].value);
			return;
		}
	}

	// Iterate through the table in a similar fashion,
	// until an empty spot is found in [0, hash)
	for (int i = 0; i < hash; ++i) {
		int key_before = atomicCAS(&new_entries[i].key,
									KEY_INVALID, key_to_add);
		if (key_before == KEY_INVALID) {
			atomicExch(&new_entries[i].value, old_entries[idx].value);
			return;
		}
	}

	// End should be reached if the table is full, impossible in this case
}

/* 
 * The hashtable constructor. Initialises the hashtable dimensions and clears
 * the VRAM memory.
 */
GpuHashTable::GpuHashTable(int size) {
	cudaError_t error_code;

	hashtable.num_elements = 0;
	hashtable.max_elements = size;
	hashtable.entries = nullptr;

	error_code = cudaMalloc(&hashtable.entries, size * sizeof(entry_t));
	DIE(error_code != cudaSuccess, "Failed to Allocate VRAM");
	error_code = cudaMemset(hashtable.entries, 0, size * sizeof(entry_t));
	DIE(error_code != cudaSuccess, "Failed to clear Allocated VRAM");
}

/*
 * Frees the VRAM memory.
 */
GpuHashTable::~GpuHashTable() {
	DIE(cudaFree(hashtable.entries) != cudaSuccess, "Failed to free hashtable");
}

/*
 * Function that allocates a new hashtable and inserts all the elements from
 * the old one into the new one, rehashing them.
 */
void GpuHashTable::reshape(int numBucketsReshape) {
	entry_t *new_entries;
	int new_max_elements = numBucketsReshape;
	cudaError_t error_code;

	// Check for valid input
	CHECK_ERROR_NORET(!numBucketsReshape);

	// Allocate new memory for the hashtable and clear it
	error_code = cudaMalloc(&new_entries, new_max_elements * sizeof(entry_t));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaMemset(new_entries, 0, new_max_elements * sizeof(entry_t));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Calculate the number of blocks and call de GPU function
	int num_blocks = hashtable.max_elements % BLOCK_THREADS ?
					 hashtable.max_elements / BLOCK_THREADS + 1 :
					 hashtable.max_elements / BLOCK_THREADS;
	reshape_entry<<<num_blocks, BLOCK_THREADS>>>(hashtable.entries,
					hashtable.max_elements, new_entries, new_max_elements);

	// Ensure that all threads finished
	error_code = cudaDeviceSynchronize();
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Free the old memory
	error_code = cudaFree(hashtable.entries);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	
	// Save the new hashtable
	hashtable.entries = new_entries;
	hashtable.max_elements = new_max_elements;
}

/*
 * Function to insert a numKeys batch of key-value pairs in the GPU hashtable.
 */
bool GpuHashTable::insertBatch(int *keys, int* values, int numKeys) {
	int *gpu_keys, *gpu_values;
	cudaError_t error_code;

	// Check for invalid input
	CHECK_ERROR(!keys || !values || !numKeys, false);

	// Resize the hashtable to 0.8f if the new load factor is above 0.85f
	if (static_cast<float>(hashtable.num_elements + numKeys) /
		static_cast<float>(hashtable.max_elements) > HARD_LIMIT) {
			
		reshape(static_cast<float>(hashtable.num_elements +
				numKeys) / SOFT_LIMIT);
	}

	// Allocate video memory
	error_code = cudaMalloc(&gpu_keys, numKeys * sizeof(int));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaMalloc(&gpu_values, numKeys * sizeof(int));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Copy information into the video memory
	error_code = cudaMemcpy(gpu_keys, keys, numKeys * sizeof(int),
					cudaMemcpyHostToDevice);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaMemcpy(gpu_values, values, numKeys * sizeof(int),
					cudaMemcpyHostToDevice);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Calculate number of GPU blocks needed and call the GPU function
	int num_blocks = numKeys % BLOCK_THREADS ?
					 numKeys / BLOCK_THREADS + 1 :
					 numKeys / BLOCK_THREADS;
	insert_entry<<<num_blocks, BLOCK_THREADS>>>(gpu_keys, gpu_values,
												numKeys, hashtable);

	// Ensure that all CUDA threads finish before freeing the memory
	error_code = cudaDeviceSynchronize();
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	hashtable.num_elements += numKeys;

	// Free memory
	error_code = cudaFree(gpu_keys);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaFree(gpu_values);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	return true;
}

/*
 * Function to retrieve numKeys elements from the GPU hashtable.
 */
int *GpuHashTable::getBatch(int* keys, int numKeys) {
	int *gpu_keys, *gpu_values, *result;
	cudaError_t error_code;

	// Check parameters validity
	CHECK_ERROR(!keys || !numKeys, nullptr);

	// Allocate memory in RAM & VRAM
	result = (int *)malloc(numKeys * sizeof(int));
	DIE(!result, "Malloc");
	error_code = cudaMalloc(&gpu_keys, numKeys * sizeof(int));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaMalloc(&gpu_values, numKeys * sizeof(int));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Clear allocated memory and initialize it
	error_code = cudaMemset(gpu_values, -1, numKeys * sizeof(int));
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaMemcpy(gpu_keys, keys, numKeys * sizeof(int),
							cudaMemcpyHostToDevice);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Calculate number of GPU blocks needed and call the GPU function
	int num_blocks = numKeys % BLOCK_THREADS ?
					 numKeys / BLOCK_THREADS + 1 :
					 numKeys / BLOCK_THREADS;
	get_entry<<<num_blocks, BLOCK_THREADS>>>(gpu_keys, gpu_values,
											 numKeys, hashtable);

	// Make sure all devices finished finding keys
	error_code = cudaDeviceSynchronize();
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Copy the results back in memory
	error_code = cudaMemcpy(result, gpu_values, numKeys * sizeof(int),
							cudaMemcpyDeviceToHost);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	// Free the VRAM memory
	error_code = cudaFree(gpu_keys);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));
	error_code = cudaFree(gpu_values);
	DIE(error_code != cudaSuccess, cudaGetErrorString(error_code));

	return result;
}

/*
 * Computes the floating point division between the current number of elements
 * and the maximum number of elements in the hashtable.
 */
float GpuHashTable::loadFactor() {
	return static_cast<float>(hashtable.num_elements) /
		static_cast<float>(hashtable.max_elements);
}

/*********************************************************/

#define HASH_INIT GpuHashTable GpuHashTable(1);
#define HASH_RESERVE(size) GpuHashTable.reshape(size);

#define HASH_BATCH_INSERT(keys, values, numKeys) GpuHashTable.insertBatch(keys, values, numKeys)
#define HASH_BATCH_GET(keys, numKeys) GpuHashTable.getBatch(keys, numKeys)

#define HASH_LOAD_FACTOR GpuHashTable.loadFactor()

#include "./test_map.cpp"
