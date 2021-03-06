/*
* Copyright (c) 2016 Jean-Noel Braun.
*
* Permission is hereby granted, free of charge, to any person obtaining a copy
* of this software and associated documentation files (the "Software"), to deal
* in the Software without restriction, including without limitation the rights
* to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
* copies of the Software, and to permit persons to whom the Software is
* furnished to do so, subject to the following conditions:
*
* The above copyright notice and this permission notice shall be included in
* all copies or substantial portions of the Software.
*
* THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
* IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
* FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
* AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
* LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
* OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
* SOFTWARE.
*/


#ifdef BCNN_USE_CUDA

#include <bh/bh.h>

#include "bcnn/bcnn.h"
#include "bcnn_utils.h"

__global__ void _bcnn_forward_activation_layer_kernel(float *x, int sz, bcnn_activation a)
{
    int i = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (i < sz) {
        switch (a) {
        case TANH:
            x[i] = (exp(2 * x[i]) - 1) / (exp(2 * x[i]) + 1);
            break;
        case RELU:
            x[i] = x[i] * (x[i] > 0);
            break;
        case RAMP:
            x[i] = x[i] * (x[i] > 0) + 0.1 * x[i];
            break;
        case CLAMP:
            x[i] = bh_clamp(x[i], 0, 1);
            break;
        case NONE:
            break;
        default:
            break;
        }
    }
    return;
}

int bcnn_forward_activation_gpu(float *x, int sz, bcnn_activation a)
{
    _bcnn_forward_activation_layer_kernel<<<bcnn_cuda_gridsize(sz), BCNN_CUDA_THREADS>>>(x,
        sz, a);
    return BCNN_SUCCESS;
}

int bcnn_forward_activation_layer_gpu(bcnn_layer *layer, bcnn_node *src_node, bcnn_node *dst_node)
{
    bcnn_tensor src = src_node->tensor;
    bcnn_tensor dst = dst_node->tensor;
    int sz = bcnn_tensor_get_size(&dst);

    dst.data_gpu = src.data_gpu;
    bcnn_forward_activation_gpu(dst.data_gpu, sz, layer->activation);
    bcnn_cuda_check(cudaPeekAtLastError());

    return BCNN_SUCCESS;
}


__global__ void _bcnn_backward_activation_layer_kernel(float *x, float *diff, int sz, bcnn_activation a)
{
    int i = (blockIdx.x + blockIdx.y * gridDim.x) * blockDim.x + threadIdx.x;
    if (i < sz) {
        switch (a) {
        case TANH:
            diff[i] *= (1 - x[i] * x[i]);
            break;
        case RELU:
            diff[i] *= ((float)(x[i] > 0));
            break;
        case RAMP:
            diff[i] *= ((float)(x[i] > 0) + 0.1f);
            break;
        case CLAMP:
            diff[i] *= (float)(x[i] > 0.0f && (x[i] < 1.0f));
            break;
        case NONE:
            break;
        default:
            break;
        }
    }
}

int bcnn_backward_activation_gpu(float *x, float *dx, int sz, bcnn_activation a)
{
    _bcnn_backward_activation_layer_kernel<<<bcnn_cuda_gridsize(sz), BCNN_CUDA_THREADS>>>(x, dx, 
        sz, a);
    return BCNN_SUCCESS;
}

int bcnn_backward_activation_layer_gpu(bcnn_layer *layer, bcnn_node *src_node, bcnn_node *dst_node)
{
    bcnn_tensor src = src_node->tensor;
    bcnn_tensor dst = dst_node->tensor;
    int sz = bcnn_tensor_get_size(&dst);
    
    bcnn_backward_activation_gpu(dst.data_gpu, dst.grad_data_gpu, sz, layer->activation);
    bcnn_cuda_check(cudaPeekAtLastError());
    src.grad_data_gpu = dst.grad_data_gpu;

    return BCNN_SUCCESS;
}


#endif