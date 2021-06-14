using FluxRC, KitBase, Plots, LinearAlgebra

using PyCall

py"""
import numpy
def get_phifj_solution_grad_tri(order, P1, Np, Nflux, elem_nfaces, V, Vf):

    correction_coeffs = numpy.zeros( shape=(Np, elem_nfaces*P1) )

    phifj_solution_r = numpy.zeros( shape=(Np, Nflux) )
    phifj_solution_s = numpy.zeros( shape=(Np, Nflux) )

    tmp = 1./numpy.sqrt(2)

    nhat = numpy.zeros(shape=(Nflux,2))
    nhat[0:P1, 0] =  0.0
    nhat[0:P1, 1] = -1.0

    nhat[P1:2*P1, :] = tmp

    nhat[2*P1:, 0] = -1
    nhat[2*P1:, 1] = 0.0

    #wgauss, rgauss = get_gauss_nodes(order)
    rgauss, wgauss = numpy.polynomial.legendre.leggauss(order+1)

    for m in range(Np):
        for face in range(3):
            modal_basis_along_face = Vf[ face*P1:(face+1)*P1, m ]
            correction_coeffs[m, face*P1:(face+1)*P1] = modal_basis_along_face*wgauss

    # correct the coefficients for face 2 with the Hypotenuse length
    correction_coeffs[:, P1:2*P1] *= numpy.sqrt(2)

    # Multiply the correction coefficients with the Dubiner basis
    # functions evaluated at the solution and flux points to get the
    # correction functions
    phifj_solution = V.dot(correction_coeffs)

    # multiply each row of the correction function with the
    # transformed element normals. These matrices will be used to
    # compute the gradients and flux divergence
    for m in range(Np):
        phifj_solution_r[m, :] = phifj_solution[m, :] * nhat[:, 0]
        phifj_solution_s[m, :] = phifj_solution[m, :] * nhat[:, 1]

    # stack the matrices
    phifj_grad = numpy.zeros( shape=(3*Np, Nflux) )
    phifj_grad[:Np,     :] = phifj_solution_r[:, :]
    phifj_grad[Np:2*Np, :] = phifj_solution_s[:, :]

    return phifj_solution, phifj_grad
"""



Vfp = zeros(9, 6)
for i in 1:3, j in 1:3
    Vfp[(i-1)*3 + j, :] .= ψf[i, j, :]
end

pyfi, pyfi_grad = py"get_phifj_solution_grad_tri"(N, N+1, Np, 3*(N+1), N+1, V, Vfp)

pyfi[:, 9]

ϕ[3, 3, :]



cd(@__DIR__)
ps = UnstructPSpace("square.msh")

N = deg = 2
Np = nsp = (N + 1) * (N + 2) ÷ 2
ncell = size(ps.cellid, 1)
nface = size(ps.faceType, 1)

J = rs_jacobi(ps.cellid, ps.points)

spg = global_sp(ps.points, ps.cellid, N)
fpg = global_fp(ps.points, ps.cellid, N)

pl, wl = tri_quadrature(N)
V = vandermonde_matrix(N, pl[:, 1], pl[:, 2])
Vr, Vs = ∂vandermonde_matrix(N, pl[:, 1], pl[:, 2]) 
∂l = ∂lagrange(V, Vr, Vs)

ϕ = correction_field(N, V)

σ = zeros(3, N+1, Np)
for k = 1:Np
    for j = 1:N+1
        for i = 1:3
            σ[i, j, k] = wf[i, j] * ψf[i, j, k]
        end
    end
end

ϕ = zeros(3, N+1, Np)
for f = 1:3, j = 1:N+1, i = 1:Np
    ϕ[f, j, i] = sum(σ[f, j, :] .* V[i, :])
end










pf, wf = triface_quadrature(N)
ψf = zeros(3, N+1, Np)
for i = 1:3
    ψf[i, :, :] .= vandermonde_matrix(N, pf[i, :, 1], pf[i, :, 2])
end

lf = zeros(3, N+1, Np)
for i = 1:3, j = 1:N+1
    lf[i, j, :] .= V' \ ψf[i, j, :]
end

a = 1.0
u = zeros(size(ps.cellid, 1), Np)
for i in axes(u, 1), j in axes(u, 2)
    u[i, j] = 1.0#exp(-300 * ((spg[i, j, 1] - 0.5)^2 + (spg[i, j, 2] - 0.5)^2))
end

f = zeros(size(ps.cellid, 1), Np, 2)
for i in axes(f, 1)
    #xr, yr = ps.points[ps.cellid[i, 2], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    #xs, ys = ps.points[ps.cellid[i, 3], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    for j in axes(f, 2)
        fg = a * u[i, j]
        gg = a * u[i, j]
        #f[i, j, :] .= [ys * fg - xs * gg, -yr * fg + xr * gg] ./ det(J[i])
        f[i, j, :] .= inv(J[i]) * [fg, gg] #/ det(J[i])
    end
end # √

u_face = zeros(ncell, 3, deg+1)
f_face = zeros(ncell, 3, deg+1, 2)
for i in 1:ncell, j in 1:3, k in 1:deg+1
    u_face[i, j, k] = sum(u[i, :] .* lf[j, k, :])
    f_face[i, j, k, 1] = sum(f[i, :, 1] .* lf[j, k, :])
    f_face[i, j, k, 2] = sum(f[i, :, 2] .* lf[j, k, :])
end # √

n = [[0.0, -1.0], [1/√2, 1/√2], [-1.0, 0.0]]
fn_face = zeros(ncell, 3, deg+1)
for i in 1:ncell, j in 1:3, k in 1:deg+1
    fn_face[i, j, k] = sum(f_face[i, j, k, :] .* n[j])
end

f_interaction = zeros(ncell, 3, deg+1, 2)
au = zeros(2)
for i = 1:ncell, j = 1:3, k = 1:deg+1
    fL = J[i] * f_face[i, j, k, :]

    ni, nj, nk = neighbor_fpidx([i, j, k], ps, fpg)

    fR = zeros(2)
    if ni > 0
        fR .= J[ni] * f_face[ni, nj, nk, :]

        @. au = (fL - fR) / (u_face[i, j, k] - u_face[ni, nj, nk] + 1e-6)
        @. f_interaction[i, j, k, :] = 
            0.5 * (fL + fR) -
            0.5 * abs(au) * (u_face[i, j, k] - u_face[ni, nj, nk])
    else
        @. f_interaction[i, j, k, :] = 0.0
    end

    f_interaction[i, j, k, :] .= inv(J[i]) * f_interaction[i, j, k, :]
end

fn_interaction = zeros(ncell, 3, deg+1)
for i in 1:ncell
    for j in 1:3, k in 1:deg+1
        fn_interaction[i, j, k] = sum(f_interaction[i, j, k, :] .* n[j])
    end
end

rhs1 = zeros(ncell, nsp)
for i in axes(rhs1, 1), j in axes(rhs1, 2)
    rhs1[i, j] = -sum(f[i, :, 1] .* ∂l[j, :, 1]) - sum(f[i, :, 2] .* ∂l[j, :, 2])
end

rhs2 = zero(rhs1)
for i in 1:ncell
    xr, yr = ps.points[ps.cellid[i, 2], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    xs, ys = ps.points[ps.cellid[i, 3], 1:2] - ps.points[ps.cellid[i, 1], 1:2]
    J = xr * ys - xs * yr
    
    if ps.cellType[i] != 1
        for j in 1:nsp
            rhs2[i, j] = - sum((fn_interaction[i, :, :] .- fn_face[i, :, :]) .* ϕ[:, :, j]) / J
        end
    end
end




















