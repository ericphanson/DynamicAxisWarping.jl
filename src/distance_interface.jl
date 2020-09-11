# methods for estimating dtw #

abstract type DTWDistance{D <: Union{Function, Distances.PreMetric}} <: Distances.SemiMetric end


"""
    struct DTW{D,N} <: DTWDistance{D}

# Keyword arguments:
- `radius`: The maximum allowed deviation of the matching path from the diagonal
- `dist`: Inner distance
- `transportcost` If >1, an additional penalty factor for non-diagonal moves is added.
- `normalizer`: defaults to `Nothing`

If the two time-series are of equal length, [`dtw_cost`](@ref) is called, if not, [`dtwnn`](@ref) is called.
"""
struct DTW{D,N} <: DTWDistance{D}
    "The maximum allowed deviation of the matching path from the diagonal"
    radius::Int
    dist::D
    "If >1, an additional penalty factor for non-diagonal moves is added."
    transportcost::Float64
end
DTW(r,dist::D=SqEuclidean(); transportcost=1, normalizer::Type{N}=Nothing) where {D,N} = DTW{D, N}(r,dist,transportcost)
DTW(;radius,dist=SqEuclidean(), transportcost=1, normalizer::Type{N}=Nothing) where {N} = DTW{typeof(dist), N}(radius,dist,transportcost)

"""
    struct SoftDTW{D, T} <: DTWDistance{D}

# Arguments:
- `γ`: smoothing parameter
- `dist`
- `transportcost`
"""
Base.@kwdef struct SoftDTW{D,T} <: DTWDistance{D}
    γ::T
    "The maximum allowed deviation of the matching path from the diagonal"
    dist::D = SqEuclidean()
    "If >1, an additional penalty factor for non-diagonal moves is added."
    transportcost::Float64 = 1.0
    SoftDTW(γ, dist=SqEuclidean(),transportcost=1) = new{typeof(dist), typeof(γ)}(γ,dist,transportcost)
end


"""
    struct FastDTW{D} <: DTWDistance{D}

- `radius`
- `dist` inner distance
"""
Base.@kwdef struct FastDTW{D} <: DTWDistance{D}
    radius::Int
    dist::D = SqEuclidean()
    FastDTW(r, dist=SqEuclidean()) = new{typeof(dist)}(r, dist)
end



function Distances.evaluate(d::DTW{<:Any,N}, x, y; kwargs...) where N
    if lastlength(x) == lastlength(y)
        x, y = normalize(N, x), normalize(N, y)
        return dtw_cost(x, y, d.dist, d.radius; transportcost = d.transportcost, kwargs...)
    end
    if lastlength(x) > lastlength(y)
        x, y = y, x
    end
    dtwnn(
        x,
        y,
        d.dist,
        d.radius,
        N;
        prune_endpoints = false,
        transportcost = d.transportcost,
        kwargs...,
    ).cost
end

Distances.evaluate(d::SoftDTW, x, y) = soft_dtw_cost(x, y, d.dist, γ=d.γ)
Distances.evaluate(d::FastDTW, x, y) =
    fastdtw(x, y, d.dist, d.radius)[1]

distpath(d::DTW, x, y) = dtw(x, y, d.dist; transportcost=d.transportcost)
distpath(d::DTW, x, y, i2min::AbstractVector, i2max::AbstractVector; transportcost=d.transportcost) =
    dtw(x, y, i2min, i2max, d.dist)
distpath(d::FastDTW, x, y) = fastdtw(x, y, d.dist, d.radius)

(d::DTWDistance)(x,y;kwargs...) = Distances.evaluate(d,x,y;kwargs...)

"""
    distance_profile(d::DTWDistance, Q::AbstractArray{S}, T::AbstractArray{S}; kwargs...) where S

Optimized method for computing the distance profile using DTW distances. kwargs are sent to [`dtwnn`](@ref).
"""
function SlidingDistancesBase.distance_profile(d::DTW{<:Any,N}, Q::AbstractArray{S}, T::AbstractArray{S}; kwargs...) where {N,S}
    m = lastlength(Q)
    n = lastlength(T)
    n >= m || throw(ArgumentError("Q cannot be longer than T"))
    l = n-m+1
    res = dtwnn(Q, T, d.dist, d.radius, N; saveall=true, kwargs...)
    res.dists
end
