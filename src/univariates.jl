#### Domain && Support

immutable RealInterval
    lb::Float64
    ub::Float64

    RealInterval(lb::Real, ub::Real) = new(float64(lb), float64(ub))
end

minimum(r::RealInterval) = r.lb
maximum(r::RealInterval) = r.ub
in(x::Real, r::RealInterval) = (r.lb <= float64(x) <= r.ub)

isbounded(d::UnivariateDistribution) = isupperbounded(d) && islowerbounded(d)
hasfinitesupport(d::DiscreteUnivariateDistribution) = isbounded(d)
hasfinitesupport(d::ContinuousUnivariateDistribution) = false

function insupport!{D<:UnivariateDistribution}(r::AbstractArray, d::Union(D,Type{D}), X::AbstractArray)
    length(r) == length(X) ||
        throw(DimensionMismatch("Inconsistent array dimensions."))
    for i in 1 : length(X)
        @inbounds r[i] = insupport(d, X[i])
    end
    return r
end

insupport{D<:UnivariateDistribution}(d::Union(D,Type{D}), X::AbstractArray) = 
     insupport!(BitArray(size(X)), d, X)

## macros to declare support

macro distr_support(D, lb, ub)
    Dty = eval(D)
    @assert Dty <: UnivariateDistribution

    # determine whether is it upper & lower bounded
    D_is_lbounded = !(lb == :(-Inf))
    D_is_ubounded = !(ub == :Inf)
    D_is_bounded = D_is_lbounded && D_is_ubounded

    D_has_constantbounds = (isa(ub, Number) || ub == :Inf) &&
                           (isa(lb, Number) || lb == :(-Inf))

    paramdecl = D_has_constantbounds ? :(::Union($D, Type{$D})) : :(d::$D)

    insuppcomp = (D_is_lbounded && D_is_ubounded)  ? :(($lb) <= x <= $(ub)) :
                 (D_is_lbounded && !D_is_ubounded) ? :(x >= $(lb)) :
                 (!D_is_lbounded && D_is_ubounded) ? :(x <= $(ub)) : :true

    support_funs = 

    support_funs = if Dty <: DiscreteUnivariateDistribution
        if D_is_bounded
            quote
                support($(paramdecl)) = int($lb):int($ub)
            end
        end
    else
        quote
            support($(paramdecl)) = RealInterval($lb, $ub)
        end
    end

    insupport_funs = if Dty <: DiscreteUnivariateDistribution
        quote 
            insupport($(paramdecl), x::Real) = isinteger(x) && ($insuppcomp)
            insupport($(paramdecl), x::Integer) = $insuppcomp
        end
    else
        @assert Dty <: ContinuousUnivariateDistribution
        quote
            insupport($(paramdecl), x::Real) = $insuppcomp
        end
    end

    # overall
    esc(quote
        islowerbounded(::Union($D, Type{$D})) = $(D_is_lbounded)
        isupperbounded(::Union($D, Type{$D})) = $(D_is_ubounded)
        isbounded(::Union($D, Type{$D})) = $(D_is_bounded)
        minimum(d::$D) = $lb
        maximum(d::$D) = $ub
        $(support_funs)
        $(insupport_funs)
    end)
end


##### generic methods (fallback) #####

## sampling

rand(d::UnivariateDistribution) = quantile(d, rand())

rand!(d::UnivariateDistribution, A::AbstractArray) = _rand!(sampler(d), A)
rand(d::UnivariateDistribution, n::Int) = _rand!(sampler(d), Array(eltype(d), n))
rand(d::UnivariateDistribution, shp::Dims) = _rand!(sampler(d), Array(eltype(d), shp))

## statistics

std(d::UnivariateDistribution) = sqrt(var(d))
median(d::UnivariateDistribution) = quantile(d, 0.5)
modes(d::UnivariateDistribution) = [mode(d)]
entropy(d::UnivariateDistribution, b::Real) = entropy(d) / log(b)

isplatykurtic(d::UnivariateDistribution) = kurtosis(d) > 0.0
isleptokurtic(d::UnivariateDistribution) = kurtosis(d) < 0.0
ismesokurtic(d::UnivariateDistribution) = kurtosis(d) == 0.0

function kurtosis(d::Distribution, correction::Bool)
    if correction
        return kurtosis(d)
    else
        return kurtosis(d) + 3.0
    end
end

excess(d::Distribution) = kurtosis(d)
excess_kurtosis(d::Distribution) = kurtosis(d)
proper_kurtosis(d::Distribution) = kurtosis(d, false)


#### pdf, cdf, and friends

# pdf

pdf(d::DiscreteUnivariateDistribution, x::Int) = throw(MethodError(pdf, (d, x)))
pdf(d::DiscreteUnivariateDistribution, x::Integer) = pdf(d, int(x))
pdf(d::DiscreteUnivariateDistribution, x::Real) = isinteger(x) ? pdf(d, int(x)) : 0.0

pdf(d::ContinuousUnivariateDistribution, x::Float64) = throw(MethodError(pdf, (d, x)))
pdf(d::ContinuousUnivariateDistribution, x::Real) = pdf(d, float64(x))

# logpdf

logpdf(d::DiscreteUnivariateDistribution, x::Int) = log(pdf(d, x))
logpdf(d::DiscreteUnivariateDistribution, x::Integer) = logpdf(d, int(x))
logpdf(d::DiscreteUnivariateDistribution, x::Real) = isinteger(x) ? logpdf(d, int(x)) : -Inf

logpdf(d::ContinuousUnivariateDistribution, x::Float64) = log(pdf(d, x))
logpdf(d::ContinuousUnivariateDistribution, x::Real) = logpdf(d, float64(x))

# cdf

function cdf(d::DiscreteUnivariateDistribution, x::Int)
    c = 0.0
    for y = minimum(d):floor(Int,x)
        c += pdf(d, y)
    end 
    return c
end

cdf(d::DiscreteUnivariateDistribution, x::Real) = cdf(d, floor(Int,x))

cdf(d::ContinuousUnivariateDistribution, x::Float64) = throw(MethodError(cdf, (d, x)))
cdf(d::ContinuousUnivariateDistribution, x::Real) = cdf(d, float64(x))

# ccdf

ccdf(d::DiscreteUnivariateDistribution, x::Int) = 1.0 - cdf(d, x)
ccdf(d::DiscreteUnivariateDistribution, x::Real) = ccdf(d, floor(Int,x)) 
ccdf(d::ContinuousUnivariateDistribution, x::Float64) = 1.0 - cdf(d, x)
ccdf(d::ContinuousUnivariateDistribution, x::Real) = ccdf(d, float64(x))

# logcdf

logcdf(d::DiscreteUnivariateDistribution, x::Int) = log(cdf(d, x))
logcdf(d::DiscreteUnivariateDistribution, x::Real) = logcdf(d, floor(Int,x))
logcdf(d::ContinuousUnivariateDistribution, x::Float64) = log(cdf(d, x))
logcdf(d::ContinuousUnivariateDistribution, x::Real) = logcdf(d, float64(x))

# logccdf

logccdf(d::DiscreteUnivariateDistribution, x::Int) = log(ccdf(d, x))
logccdf(d::DiscreteUnivariateDistribution, x::Real) = logccdf(d, floor(Int,x))
logccdf(d::ContinuousUnivariateDistribution, x::Float64) = log(ccdf(d, x))
logccdf(d::ContinuousUnivariateDistribution, x::Real) = logccdf(d, float64(x))

# quantile

quantile(d::UnivariateDistribution, p::Float64) = throw(MethodError(quantile, (d, p)))
quantile(d::UnivariateDistribution, p::Real) = quantile(d, float64(p))

function quantile_bisect(d::ContinuousUnivariateDistribution, p::Float64, 
                         lx::Float64, rx::Float64, tol::Float64)

    # find quantile using bisect algorithm
    cl = cdf(d, lx)
    cr = cdf(d, rx)
    @assert cl <= p <= cr
    while rx - lx > tol
        m = 0.5 * (lx + rx)
        c = cdf(d, m)
        if p > c
            cl = c
            lx = m
        else
            cr = c
            rx = m
        end 
    end
    return 0.5 * (lx + rx)
end

quantile_bisect(d::ContinuousUnivariateDistribution, p::Float64) = 
    quantile_bisect(d, p, minimum(d), maximum(d), 1.0e-12)


# cquantile

cquantile(d::UnivariateDistribution, p::Float64) = quantile(d, 1.0 - p)
cquantile(d::UnivariateDistribution, p::Real) = cquantile(d, float64(p))

# invlogcdf

invlogcdf(d::UnivariateDistribution, lp::Float64) = quantile(d, exp(lp))
invlogcdf(d::UnivariateDistribution, lp::Real) = invlogcdf(d, float64(lp))

# invlogccdf

invlogccdf(d::UnivariateDistribution, lp::Float64) = quantile(d, -expm1(lp))
invlogccdf(d::UnivariateDistribution, lp::Real) = invlogccdf(d, float64(lp))

# gradlogpdf

gradlogpdf(d::ContinuousUnivariateDistribution, x::Float64) = throw(MethodError(gradlogpdf, (d, x)))
gradlogpdf(d::ContinuousUnivariateDistribution, x::Real) = gradlogpdf(d, float64(x))


# vectorized versions
for fun in [:pdf, :logpdf, 
            :cdf, :logcdf, 
            :ccdf, :logccdf, 
            :invlogcdf, :invlogccdf, 
            :quantile, :cquantile]

    _fun! = symbol(string('_', fun, '!'))
    fun! = symbol(string(fun, '!'))

    @eval begin
        function ($_fun!)(r::AbstractArray, d::UnivariateDistribution, X::AbstractArray)
            for i in 1 : length(X)
                r[i] = ($fun)(d, X[i])
            end
            return r
        end

        function ($fun!)(r::AbstractArray, d::UnivariateDistribution, X::AbstractArray)
            length(r) == length(X) ||
                throw(ArgumentError("Inconsistent array dimensions."))
            $(_fun!)(r, d, X)
        end

        ($fun)(d::UnivariateDistribution, X::AbstractArray) = 
            $(_fun!)(Array(Float64, size(X)), d, X)
    end
end

function _pdf!(r::AbstractArray, d::DiscreteUnivariateDistribution, X::UnitRange)
    vl = vfirst = first(X)
    vr = vlast = last(X)
    n = vlast - vfirst + 1
    if islowerbounded(d) 
        lb = minimum(d)
        if vl < lb
            vl = lb
        end
    end
    if isupperbounded(d)
        ub = maximum(d)
        if vr > ub
            vr = ub
        end
    end

    # fill left part
    if vl > vfirst
        for i = 1:(vl - vfirst)
            r[i] = 0.0
        end
    end

    # fill central part: with non-zero pdf
    fm1 = vfirst - 1
    for v = vl:vr
        r[v - fm1] = pdf(d, v)
    end

    # fill right part
    if vr < vlast
        for i = (vr-vfirst+2):n
            r[i] = 0.0
        end
    end
    return r
end


abstract RecursiveProbabilityEvaluator

function _pdf!(r::AbstractArray, d::DiscreteUnivariateDistribution, X::UnitRange, rpe::RecursiveProbabilityEvaluator)
    vl = vfirst = first(X)
    vr = vlast = last(X)
    n = vlast - vfirst + 1
    if islowerbounded(d) 
        lb = minimum(d)
        if vl < lb
            vl = lb
        end
    end
    if isupperbounded(d)
        ub = maximum(d)
        if vr > ub
            vr = ub
        end
    end

    # fill left part
    if vl > vfirst
        for i = 1:(vl - vfirst)
            r[i] = 0.0
        end
    end

    # fill central part: with non-zero pdf
    if vl <= vr
        fm1 = vfirst - 1
        r[vl - fm1] = pv = pdf(d, vl)
        for v = (vl+1):vr
            r[v - fm1] = pv = nextpdf(rpe, pv, v)
        end
    end

    # fill right part
    if vr < vlast
        for i = (vr-vfirst+2):n
            r[i] = 0.0
        end
    end
    return r
end


pdf(d::DiscreteUnivariateDistribution) = isbounded(d) ? pdf(d, minimum(d):maximum(d)) : 
                                                        error("pdf(d) is not allowed when d is unbounded.")


## loglikelihood

function _loglikelihood(d::UnivariateDistribution, X::AbstractArray)
    ll = 0.0
    for i in 1:length(X)
        @inbounds ll += logpdf(d, X[i])
    end
    return ll
end

loglikelihood(d::UnivariateDistribution, X::AbstractArray) = 
    _loglikelihood(d, X)

##### specific distributions #####

const discrete_distributions = [ 
    "bernoulli",
    "binomial",
    "categorical",
    "discreteuniform",
    "geometric",
    "hypergeometric",
    "negativebinomial",
    "noncentralhypergeometric",
    "poisson",
    "skellam"  
]

const continuous_distributions = [
    "arcsine",
    "beta",
    "betaprime",
    "cauchy",
    "chisq",    # Chi depends on Chisq
    "chi",
    "cosine",  
    "exponential",
    "fdist",
    "frechet",
    "gamma", "erlang",
    "gumbel",
    "inversegamma",
    "inversegaussian",
    "kolmogorov",
    "ksdist",
    "ksonesided",
    "laplace",
    "levy",
    "logistic",
    "lognormal",
    "noncentralbeta",
    "noncentralchisq",
    "noncentralf",
    "noncentralt",
    "normal",
    "normalcanon",
    "pareto",
    "rayleigh",
    "symtriangular",
    "tdist",
    "triangular",
    "uniform",
    "vonmises",
    "weibull"
]


for dname in discrete_distributions
    include(joinpath("univariate", "discrete", "$(dname).jl"))
end

for dname in continuous_distributions
    include(joinpath("univariate", "continuous", "$(dname).jl"))
end

