/*
 * Tema 2 ASC
 * Craciunoiu Cezar
 * 2020 Spring
 */
#include "utils.h"
#include <cblas.h>

/* 
 * Calculates the equation using cblas functions efficiently. All multiplication
 * functions use the property that one operand is a triangular matrix.
 */
double *my_solver(int N, double *A, double *B) {
	double *power, *left_product, *right_product;

	power = left_product = right_product = NULL;
	left_product = malloc(sizeof(double) * N * N);
	right_product = malloc(sizeof(double) * N * N);
	power = malloc(sizeof(double) * N * N);
	if (left_product == NULL || right_product == NULL || power == NULL) {
		exit(12);
	}

	// Copies A in power
	cblas_dcopy(N * N, A, 1, power, 1);
	// Copies B in left_product
	cblas_dcopy(N * N, B, 1, left_product, 1);
	// Copies B in right_product
	cblas_dcopy(N * N, B, 1, right_product, 1);
	// Calculates the left side of the sum and writes it in left_product
	cblas_dtrmm(CblasRowMajor, CblasRight, CblasUpper, CblasTrans,
				CblasNonUnit, N, N, 1.0, A, N, left_product, N);
	// Calculates the power of A by multiplying A with itself
	cblas_dtrmm(CblasRowMajor, CblasRight, CblasUpper, CblasNoTrans,
				CblasNonUnit, N, N, 1.0, A, N, power, N);
	// Calculates the right side of the sum and writes it in right_product
	cblas_dtrmm(CblasRowMajor, CblasLeft, CblasUpper, CblasNoTrans,
				CblasNonUnit, N, N, 1.0, power, N, right_product, N);
	// Adds the 2 vectors and writes the result in right_product
	cblas_daxpy(N * N, 1, left_product, 1, right_product, 1);

	free(left_product);
	free(power);
	return right_product;
}
