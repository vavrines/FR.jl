using FluxRC, KitBase, Plots, LinearAlgebra
using ProgressMeter: @showprogress

cd(@__DIR__)
ps = TriFRPSpace("../assets/sod.msh", 2)

eids = (419, 418, 420, 423)
for i in eachindex(ps.cellType)
    if i ∉ eids
        if ps.cellType[i] == 1
            if ps.cellCenter[i, 2] < 0.014 || ps.cellCenter[i, 2] > 0.0835
                ps.cellType[i] = 2
            end
        end
    end
end

γ = 5 / 3
u0 = zeros(size(ps.cellid, 1), ps.np, 4)
for i in axes(u0, 1), j in axes(u0, 2)
    #if ps.xpg[i, j, 1] < 0.5
    if ps.cellCenter[i, 1] < 0.5
        prim = [1.0, 0.0, 0.0, 0.5]
    else
        prim = [0.3, 0.0, 0.0, 0.625]
    end

    u0[i, j, :] .= prim_conserve(prim, γ)
end

function dudt!(du, u, p, t)
    cellType, J, lf, cell_normal, fpn, ∂l, ϕ, γ = p
    ncell = size(u, 1)
    nsp = size(u, 2)
    deg = size(fpn, 3) - 1

    f = zeros(ncell, nsp, 4, 2)
    for i in axes(f, 1)
        for j in axes(f, 2)
            fg, gg = euler_flux(u[i, j, :], γ)
            for k in axes(f, 3)
                f[i, j, k, :] .= inv(J[i]) * [fg[k], gg[k]]
            end
        end
    end

    u_face = zeros(ncell, 3, deg + 1, 4)
    f_face = zeros(ncell, 3, deg + 1, 4, 2)
    for i in 1:ncell, j in 1:3, k in 1:deg+1, l in 1:4
        u_face[i, j, k, l] = sum(u[i, :, l] .* lf[j, k, :])
        f_face[i, j, k, l, 1] = sum(f[i, :, l, 1] .* lf[j, k, :])
        f_face[i, j, k, l, 2] = sum(f[i, :, l, 2] .* lf[j, k, :])
    end

    n = [[0.0, -1.0], [1 / √2, 1 / √2], [-1.0, 0.0]]

    fn_face = zeros(ncell, 3, deg + 1, 4)
    for i in 1:ncell, j in 1:3, k in 1:deg+1, l in 1:4
        fn_face[i, j, k, l] = dot(f_face[i, j, k, l, :], n[j])
    end

    fn_interaction = zeros(ncell, 3, deg + 1, 4)
    for i in 1:ncell, j in 1:3, k in 1:deg+1
        uL = local_frame(u_face[i, j, k, :], cell_normal[i, j, 1], cell_normal[i, j, 2])

        ni, nj, nk = fpn[i, j, k]

        fwn_local = zeros(4)
        if ni > 0
            uR = local_frame(
                u_face[ni, nj, nk, :],
                cell_normal[i, j, 1],
                cell_normal[i, j, 2],
            )
            flux_hll!(fwn_local, uL, uR, γ, 1.0)
        elseif cellType[i] == 2
            _uR = u_face[i, j, k, :]
            _uR[3] = -_uR[3]
            uR = local_frame(_uR, cell_normal[i, j, 1], cell_normal[i, j, 2])
            flux_hll!(fwn_local, uL, uR, γ, 1.0)
        end
        fwn_global = global_frame(fwn_local, cell_normal[i, j, 1], cell_normal[i, j, 2])

        fwn_xy = zeros(4, 2)
        for idx in 1:4
            fwn_xy[idx, :] .= fwn_global[idx] .* cell_normal[i, j, :]
        end

        fws_rs = zeros(4, 2)
        for idx in 1:4
            fws_rs[idx, :] .= inv(J[i]) * fwn_xy[idx, :]
        end

        fwns = [sum(fws_rs[idx, :] .* n[j]) for idx in 1:4]
        #fwns = [sum(fws_rs[idx, :]) for idx in 1:4]

        fn_interaction[i, j, k, :] .= fwns
    end

    rhs1 = zeros(ncell, nsp, 4)
    for i in axes(rhs1, 1), j in axes(rhs1, 2), k in 1:4
        rhs1[i, j, k] =
            -sum(f[i, :, k, 1] .* ∂l[j, :, 1]) - sum(f[i, :, k, 2] .* ∂l[j, :, 2])
    end

    rhs2 = zero(rhs1)
    for i in 1:ncell
        if ps.cellType[i] ∈ [0, 2]
            for j in 1:nsp, k in 1:4
                rhs2[i, j, k] =
                    -sum((fn_interaction[i, :, :, k] .- fn_face[i, :, :, k]) .* ϕ[:, :, j])
            end
        end
    end

    for i in 1:ncell
        if ps.cellType[i] ∈ [0, 2]
            du[i, :, :] .= rhs1[i, :, :] .+ rhs2[i, :, :]
        end
    end

    return nothing
end

tspan = (0.0, 0.1)
p = (ps.cellType, ps.J, ps.lf, ps.cellNormals, ps.fpn, ps.∂l, ps.ϕ, γ)
prob = ODEProblem(dudt!, u0, tspan, p)
dt = 0.0005
nt = tspan[end] ÷ dt |> Int
itg = init(prob, Euler(); save_everystep=false, adaptive=false, dt=dt)

@showprogress for iter in 1:nt
    step!(itg)
end

begin
    prim = zero(itg.u)
    for i in axes(prim, 1), j in axes(prim, 2)
        prim[i, j, :] .= conserve_prim(itg.u[i, j, :], γ)
        prim[i, j, 4] = 1 / prim[i, j, 4]
    end
    write_vtk(ps.points, ps.cellid, prim[:, 2, :])
end
