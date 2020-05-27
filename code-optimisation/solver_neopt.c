/*
 * Tema 2 ASC
 * Craciunoiu Cezar
 * 2020 Spring
 */
#include "utils.h"

/* Allocates space for a new matrix and copies the information from
 * the upper part to the lower part of the matrix.
 */
static double *matrix_triangular_transpose(int N, double *matrix) {
	int i, j;
	double *result = NULL;

	result = calloc(N * N, sizeof(double));
	if (result == NULL || matrix == NULL) {
		exit(12);
	}

	for (i = 0; i < N; i++) {
		for (j = i; j < N; j++) {
			result[j * N + i] = matrix[i * N + j];
		}
	}

	return result;
}

/* Allocates space for the result and calculates the sum of two matrixes */
static double *matrix_sum(int N, double *matrix_left, double *matrix_right) {
	int i, j;
	double *result = NULL;
	
	result = calloc(N * N, sizeof(double));
	if (result == NULL || matrix_left == NULL || matrix_right == NULL) {
		exit(12);
	}

	for (i = 0; i < N; i++) {
		for (j = 0; j < N; j++) {
			result[i * N + j] = matrix_left[i * N + j] +
				matrix_right[i * N + j];
		}
	}

	return result;
}

/* Calculates the multiplication of two matrixes in an unoptimised fashion
 * but still using the precondition that one is triangular
 */
static double *matrix_multiply(int N, double *matrix_left,
				double *matrix_right, char tr_left) {
	int i, j, k;
	double *result = NULL;
	
	result = calloc(N * N, sizeof(double));
	if (result == NULL || matrix_left == NULL || matrix_right == NULL) {
		exit(12);
	}
	if (tr_left == 1) {
		for (i = 0; i < N; i++) {
			for (j = 0; j < N; j++) {
				for (k = i; k < N; k++) {
					result[i * N + j] += matrix_left[i * N + k] *
						matrix_right[k * N + j];
				}
			}
		}
	} else {
		for (i = 0; i < N; i++) {
			for (j = 0; j < N; j++) {
				for (k = j; k < N; k++) {
					result[i * N + j] += matrix_left[i * N + k] *
						matrix_right[k * N + j];
				}
			}
		}
	}
	return result;
}

/* Multiplies a matrix with itself taking account that half of it
 * is filled with zeroes.
 */
static double *matrix_triangular_power(int N, double *matrix) {
	int i, j, k;
	double *result = NULL;
	
	result = calloc(N * N, sizeof(double));
	if (result == NULL || matrix == NULL) {
		exit(12);
	}

	for (i = 0; i < N; i++) {
		for (j = i; j < N; j++) {
			for (k = i; k <= j; k++) {
				result[i * N + j] += matrix[i * N + k] * matrix[k * N + j];
			}
		}
	}

	return result;
}

/*
 * Calls all functions in the correct order and frees additional memory
 * The functions called assume that matrix A is upper triangular.
 */
double *my_solver(int N, double *A, double *B) {
	double *transpose, *power, *left_product, *right_product, *sum;

	transpose = power = left_product = right_product = sum = NULL;
	transpose = matrix_triangular_transpose(N, A);
	left_product = matrix_multiply(N, B, transpose, 0);
	power = matrix_triangular_power(N, A);
	right_product = matrix_multiply(N, power, B, 1);
	sum = matrix_sum(N, left_product, right_product);

	free(transpose);
	free(left_product);
	free(power);
	free(right_product);
	return sum;
}
