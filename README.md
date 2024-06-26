[![Run Tests](https://github.com/rwth-irt/KernelDistributions.jl/actions/workflows/run_tests.yml/badge.svg)](https://github.com/rwth-irt/KernelDistributions.jl/actions/workflows/run_tests.yml)
[![Documenter](https://github.com/rwth-irt/KernelDistributions.jl/actions/workflows/documenter.yml/badge.svg)](https://github.com/rwth-irt/KernelDistributions.jl/actions/workflows/documenter.yml)
[![](https://img.shields.io/badge/docs-stable-blue.svg)](https://rwth-irt.github.io/KernelDistributions.jl)
# KernelDistributions.jl
Based on [Distributions.jl](https://github.com/JuliaStats/Distributions.jl) but slimmed down to enable CUDA compatibility.

Distributions are isbitstype, strongly typed and thus support execution on the GPU.
KernelDistributions offer the following interface functions:
- `DensityInterface.logdensityof(dist::KernelDistribution, x)`
- `Random.rand!(rng, dist::KernelDistribution, A)`
- `Base.rand(rng, dist::KernelDistribution, dims...)`
- `Base.eltype(::Type{<:AbstractKernelDistribution})`: Number format of the distribution, e.g. Float16

The Interface requires the following to be implemented:
- Bijectors.bijector(d): Bijector
- `rand_kernel(rng, dist::MyKernelDistribution{T})::T` generate a single random number from the distribution
- `Distributions.logpdf(dist::MyKernelDistribution{T}, x)::T` evaluate the normalized logdensity
- `Base.maximum(d), Base.minimum(d), Distributions.insupport(d)`: Determine the support of the distribution
- `Distributions.logcdf(d, x), Distributions.invlogcdf(d, x)`: Support for Truncated{D}

Most of the time Float64 precision is not required, especially for GPU computations.
Thus, this package defaults to Float32, mostly for memory capacity reasons.
