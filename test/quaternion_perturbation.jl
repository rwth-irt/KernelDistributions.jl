# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved.

using KernelDistributions
using LinearAlgebra
using Quaternions
using Random
using StatsBase
using Test

σ = 0.01

"""
    exponential_map(x, y, z)
Convert a rotation vector to a Quaternion (formerly qrotation in Quaternions.jl)
Eq. (101) in J. Sola, „Quaternion kinematics for the error-state KF“
Exponential for quaternions can be reformulated to the exponential map using (46).
"""
function exponential_map(x, y, z)
    rotvec = [x, y, z]
    theta = norm(rotvec)
    s, c = sincos(theta / 2)
    scaleby = s / (iszero(theta) ? one(theta) : theta)
    Quaternion(c, scaleby * rotvec[1], scaleby * rotvec[2], scaleby * rotvec[3])
end

# (eq. 105, Sola2012)
function logarithmic_map(q)
    qv = [q.v1, q.v2, q.v3]
    abs_qv = norm(qv)
    ϕ = 2 * atan(abs_qv, q.s)
    u = qv / abs_qv
    ϕ * u
end

@testset "quaternion exponential and logarithmic maps" begin
    # Normalization approximation
    θ = rand(KernelNormal(0, Float32(σ)), 3)
    q = @inferred KernelDistributions.exp_map(θ)
    @test abs(q) == 1
    @test q isa QuaternionF32
    @test !isone(q)
    @test q ≈ exponential_map(θ...)
    @test θ ≈ KernelDistributions.log_map(q) ≈ logarithmic_map(q)
end

@testset "⊕ quaternion operator" begin
    θ = rand(KernelNormal(0, Float32(σ)), 3)
    q = @inferred KernelDistributions.exp_map(θ)
    # add rotation to quaternion
    qs = @inferred one(QuaternionF32) ⊕ θ
    @test qs isa QuaternionF32
    @test qs == q
end

@testset "Broadcasting ⊕ operator " begin
    θ = rand(KernelNormal(0, Float32(σ)), 3)
    q = @inferred KernelDistributions.exp_map(θ)

    qs = @inferred one(QuaternionF32) ⊕ θ
    Qs1 = @inferred one(QuaternionF32) .⊕ fill(θ, 42)
    @test reduce(&, Qs1 .== qs)
    @test Qs1 isa Vector{QuaternionF32}
    @test length(Qs1) == 42

    # scalar quaternion, "scalar" rotation
    qs2 = @inferred one(QuaternionF32) .⊕ θ
    @test qs == qs2
    # scalar quaternion, vector of rotations
    Qs2 = @inferred one(QuaternionF32) .⊕ reduce(hcat, fill(θ, 42))
    @test Qs1 == Qs2
    # vector of quaternions, "scalar" rotation
    Qs2 = @inferred fill(one(QuaternionF32), 42) .⊕ θ
    @test Qs1 == Qs2
    # vector of quaternions, vector of rotations
    Qs2 = @inferred fill(one(QuaternionF32), 42) .⊕ reduce(hcat, fill(θ, 42))
    @test Qs1 == Qs2
end

@testset "⊖ quaternion operator" begin
    θ = rand(KernelNormal(0, Float32(σ)), 3)
    q = @inferred KernelDistributions.exp_map(θ)

    qs = @inferred one(QuaternionF32) ⊕ θ
    @test qs ⊖ one(QuaternionF32) ≈ θ
    q = randn(QuaternionF32)
    qs = q ⊕ θ
    @test θ ≈ qs ⊖ q
    @test qs ⊖ q ≈ -(q ⊖ qs)
    @test (qs ⊖ q) isa Vector{Float32}
    # broadcastable?
    Qs = @inferred q .⊕ fill(θ, 42)
    Θ = @inferred Qs .⊖ q
    @test reduce(&, Θ .≈ [θ])
    @test Θ isa Vector{Vector{Float32}}
    @test length(Θ) == 42
end

@testset "mean quaternion" begin
    # Vector of quaternions
    θ = rand(KernelNormal(0, Float32(σ)), 3, 10)
    q = KernelDistributions.exp_map(θ)
    @test length(q) == 10
    w = rand(Float32, length(q)) |> weights
    q_mean = @inferred mean(q, w)
    @test q_mean isa QuaternionF32
    @test abs(q_mean) ≈ 1
    # Matrix shape
    Q = randn(QuaternionF32, (10, 5)) .|> sign
    W = rand(Float32, size(Q)) |> weights
    Q_mean = @inferred mean(Q, W)
    @test Q_mean isa QuaternionF32
    @test abs(Q_mean) ≈ 1
end

# https://en.wikipedia.org/wiki/Weighted_arithmetic_mean#Weighted_sample_covariance
function biased_quat_cov(q::AbstractVector{<:Quaternion}, w::AbstractWeights)
    μ = mean(q, w)
    diffs = q .⊖ μ
    sum(@. w * KernelDistributions.outer_product(diffs)) / sum(w)
end

# https://en.wikipedia.org/wiki/Weighted_arithmetic_mean#Reliability_weights_2
function unbiased_quat_cov(q::AbstractVector{<:Quaternion}, w::AbstractWeights)
    μ = mean(q, w)
    diffs = q .⊖ μ
    sum(@. w * KernelDistributions.outer_product(diffs)) / (sum(w) - sum(w .^ 2) / sum(w))
end

@testset "covariance rotation of quaternion" begin
    q = rand(QuaternionF32, 5) .|> sign
    w = rand(Float32, 5) |> AnalyticWeights
    μ, Σ = @inferred mean_and_cov(q, w; corrected=false)
    @test μ == mean(q, w)
    @test Σ ≈ biased_quat_cov(q, w)
    @test cov(q, w; corrected=false) ≈ biased_quat_cov(q, w)
    μ, Σ = @inferred mean_and_cov(q, w; corrected=true)
    @test μ == mean(q, w)
    @test Σ ≈ unbiased_quat_cov(q, w)
    Σ = @inferred cov(q, w; corrected=true)
    @test Σ ≈ unbiased_quat_cov(q, w)
end
