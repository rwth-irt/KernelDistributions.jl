# @license BSD-3 https://opensource.org/licenses/BSD-3-Clause
# Copyright (c) 2022, Institute of Automatic Control - RWTH Aachen University
# All rights reserved. 

using Documenter, KernelDistributions
import Documenter.Remotes: GitLab

makedocs(modules=[KernelDistributions], sitename="KernelDistributions")
deploydocs(repo="github.com/rwth-irt/KernelDistributions.jl.git")
