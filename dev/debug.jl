t1 = ib_rh(1.1, ks.gas.γ, rand(3))[2]
prim = [t1[1], t1[2], 0.0, t1[3]]

s = prim[1]^(1 - ks.gas.γ) / (2 * prim[end])

i = 8;
j = 15;

θ = atan((ps.xpg[i, j, 2, 2, 2] - 0.5) / (ps.xpg[i, j, 2, 2, 1] - 0.25))

κ = 0.3
μ = 0.204
rc = 0.05

r = sqrt((ps.xpg[i, j, 2, 2, 1] - 0.25)^2 + (ps.xpg[i, j, 2, 2, 2] - 0.5)^2)
η = r / rc

δu = κ * η * exp(μ * (1 - η^2)) * sin(θ)
δv = κ * η * exp(μ * (1 - η^2)) * cos(θ)
δT = -(ks.gas.γ - 1) * κ^2 / (2 * μ * γ) * exp(2 * μ * (1 - η^2))
δλ = 1 / δT
