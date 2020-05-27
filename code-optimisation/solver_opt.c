/*
 * Tema 2 ASC
 * Craciunoiu Cezar
 * 2020 Spring
 */
#include "utils.h"

/* Allocates space for a new matrix and copies the information from
 * the upper part to the lower part of the matrix.
 */
static double *matrix_triangular_transpose(const register int N,
				const double *matrix) {
	register int i, j;
	double *result = calloc(N * N, sizeof(double));

	if (result == NULL || matrix == NULL) {
		exit(12);
	}

	for (i = 0; i < N; ++i) {
		for (j = i; j < N; ++j) {
			result[(j + 0) * N + i] = matrix[i * N + (j + 0)];
		}
	}

	return result;
}

/* Allocates space for the result and calculates the sum of two matrixes
 * using loop unrolling to speed up execution.
 */
static double *matrix_sum(const register int N, double *matrix_left,
				const double *matrix_right) {
	register int i, j;

	if (matrix_right == NULL || matrix_left == NULL) {
		exit(12);
	}

	for (i = 0; i < N; ++i) {
		for (j = 0; j < N; j += 10) {
			matrix_left[i * N + (j + 0)] += matrix_right[i * N + (j + 0)];
			matrix_left[i * N + (j + 1)] += matrix_right[i * N + (j + 1)];
			matrix_left[i * N + (j + 2)] += matrix_right[i * N + (j + 2)];
			matrix_left[i * N + (j + 3)] += matrix_right[i * N + (j + 3)];
			matrix_left[i * N + (j + 4)] += matrix_right[i * N + (j + 4)];
			matrix_left[i * N + (j + 5)] += matrix_right[i * N + (j + 5)];
			matrix_left[i * N + (j + 6)] += matrix_right[i * N + (j + 6)];
			matrix_left[i * N + (j + 7)] += matrix_right[i * N + (j + 7)];
			matrix_left[i * N + (j + 8)] += matrix_right[i * N + (j + 8)];
			matrix_left[i * N + (j + 9)] += matrix_right[i * N + (j + 9)];
		}
	}

	return matrix_left;
}

/* Calculates the multiplication of two matrixes taking in account if
 * one matrix is superior or inferior triangular 
 */
static double *matrix_multiply(const register int N, const double *matrix_left,
				const double *matrix_right, const char tr_left) {
	register int i, j, k;
	register double sum;
	double *result = calloc(N * N, sizeof(double));
	
	if (result == NULL || matrix_right == NULL || matrix_left == NULL) {
		exit(12);
	}

	if (tr_left == 1) {
		for (i = 0; i < N; ++i) {
			for (j = 0; j < N; ++j) {
				sum = 0.0;
				for (k = i; k < N; ++k) {
					sum += matrix_left[i * N + k] * matrix_right[k * N + j];
				}
				result[i * N + j] = sum;
			}
		}
	} else {
		for (i = 0; i < N; ++i) {
			for (j = 0; j < N; ++j) {
				sum = 0.0;
				for (k = j; k < N; ++k) {
					sum += matrix_left[i * N + k] * matrix_right[k * N + j];
				}
				result[i * N + j] = sum;
			}
		}
	}

	return result;
}

/* Multiplies a matrix with itself taking account that half of it
 * is filled with zeroes.
 */
static double *matrix_triangular_power(const register int N,
				const double *matrix) {
	register int i, j, k;
	double *result = calloc(N * N, sizeof(double));

	if (result == NULL || matrix == NULL) {
		exit(12);
	}

	for (i = 0; i < N; ++i) {
		for (j = i; j < N; ++j) {
			register double sum = 0.0;
			for (k = i; k <= j; ++k) {
				sum += matrix[i * N + k] * matrix[k * N + j];
			}
			result[i * N + j] = sum;
		}
	}

	return result;
}

/*
 * Calls all functions in the correct order and frees additional memory,
 * the result is put in left_product and returned.
 * The functions called assume that matrix A is upper triangular.
 */
double *my_solver(int N, double *A, double *B) {
	double *transpose, *power, *left_product, *right_product, *sum;

	transpose = power = left_product = right_product = sum = NULL;
	transpose = matrix_triangular_transpose(N, A);
	left_product = matrix_multiply(N, B, transpose, 0);
	free(transpose);
	power = matrix_triangular_power(N, A);
	right_product = matrix_multiply(N, power, B, 1);
	free(power);
	sum = matrix_sum(N, left_product, right_product);
	free(right_product);
	return sum;
}
