## sample space/domain

# Abstract root types
#                    VariateForm | Univariate | Multivatriate | Matrixvariate |
#                    ValueSupport | Discrete | Continuous | Mixed |
#                    Sampleable{F<:VariateForm,S<:ValueSupport}
#                    Distribution{F<:VariateForm,S<:ValueSupport} <: Sampleable{F,S}
#                    SufficientStats
#                    IncompleteDistribution
#                    DistributionType{D<:Distribution} Type{D}
#                    IncompleteFormulation Union(DistributionType,IncompleteDistribution)


# Aliases
#        UnivariateDistribution{S<:ValueSupport}   = Distribution{Univariate,S}
#        MultivariateDistribution{S<:ValueSupport} = Distribution{Multivariate,S}
#        MatrixDistribution{S<:ValueSupport}       = Distribution{Matrixvariate,S}
#        NonMatrixDistribution                     = Union(UnivariateDistribution, MultivariateDistribution)
#        DiscreteDistribution{F<:VariateForm}      = Distribution{F,Discrete}
#        ContinuousDistribution{F<:VariateForm}    = Distribution{F,Continuous}
#        MixedDistribution{F<:VariateForm}         = Distribution{F,Mixed}
#        DiscreteUnivariateDistribution            = Distribution{Univariate,    Discrete}
#        ContinuousUnivariateDistribution          = Distribution{Univariate,    Continuous}
#        DiscreteMultivariateDistribution          = Distribution{Multivariate,  Discrete}
#        ContinuousMultivariateDistribution        = Distribution{Multivariate,  Continuous}
#        DiscreteMatrixDistribution                = Distribution{Matrixvariate, Discrete}
#        ContinuousMatrixDistribution              = Distribution{Matrixvariate, Continuous}


abstract VariateForm
type Univariate    <: VariateForm end
type Multivariate  <: VariateForm end
type Matrixvariate <: VariateForm end

abstract ValueSupport
type Discrete   <: ValueSupport end
type Continuous <: ValueSupport end
type Mixed      <: ValueSupport end

Base.eltype(::Type{Discrete}) = Int
Base.eltype(::Type{Continuous}) = Float64
Base.eltype(::Type{Mixed})      = Float64

## Sampleable

abstract Sampleable{F<:VariateForm, S<:ValueSupport}

Base.length(::Sampleable{Univariate}) = 1
Base.length(s::Sampleable{Multivariate}) = throw(MethodError(length, (s,)))
Base.length(s::Sampleable) = prod(size(s))

Base.size(s::Sampleable{Univariate}) = ()
Base.size(s::Sampleable{Multivariate}) = (length(s),)

Base.eltype{F,S}(s::Sampleable{F,S}) = eltype(S)
Base.eltype{F}(s::Sampleable{F,Discrete}) = Int
Base.eltype{F}(s::Sampleable{F,Continuous}) = Float64
Base.eltype{F}(s::Sampleable{F,Mixed})      = Float64

nsamples{D<:Sampleable{Univariate}}(::Type{D}, x::Number) = 1
nsamples{D<:Sampleable{Univariate}}(::Type{D}, x::AbstractArray) = length(x)
nsamples{D<:Sampleable{Multivariate}}(::Type{D}, x::AbstractVector) = 1
nsamples{D<:Sampleable{Multivariate}}(::Type{D}, x::AbstractMatrix) = size(x, 2)
nsamples{D<:Sampleable{Matrixvariate}}(::Type{D}, x::Number) = 1
nsamples{D<:Sampleable{Matrixvariate},T<:Number}(::Type{D}, x::Array{Matrix{T}}) = length(x)

## Distribution <: Sampleable

abstract Distribution{F<:VariateForm,S<:ValueSupport} <: Sampleable{F,S}

typealias UnivariateDistribution{S<:ValueSupport}   Distribution{Univariate,S}
typealias MultivariateDistribution{S<:ValueSupport} Distribution{Multivariate,S}
typealias MatrixDistribution{S<:ValueSupport}       Distribution{Matrixvariate,S}
typealias NonMatrixDistribution Union(UnivariateDistribution, MultivariateDistribution)

typealias DiscreteDistribution{ F<:VariateForm}   Distribution{F, Discrete}
typealias ContinuousDistribution{ F<:VariateForm} Distribution{F, Continuous}
typealias MixedDistribution{ F<:VariateForm}      Distribution{F, Mixed}

typealias DiscreteUnivariateDistribution     Distribution{Univariate,    Discrete}
typealias ContinuousUnivariateDistribution   Distribution{Univariate,    Continuous}
typealias MixedUnivariateDistribution        Distribution{Univariate,    Mixed}

typealias DiscreteMultivariateDistribution   Distribution{Multivariate,  Discrete}
typealias ContinuousMultivariateDistribution Distribution{Multivariate,  Continuous}
typealias ContinuousMultivariateDistribution Distribution{Multivariate,  Mixed}

typealias DiscreteMatrixDistribution         Distribution{Matrixvariate, Discrete}
typealias ContinuousMatrixDistribution       Distribution{Matrixvariate, Continuous}
typealias ContinuousMatrixDistribution       Distribution{Matrixvariate, Mixed}

variate_form{VF<:VariateForm, VS<:ValueSupport}(::Type{Distribution{VF, VS}}) = VF
variate_form{T<:Distribution}(::Type{T}) = variate_form(super(T))

value_support{VF<:VariateForm, VS<:ValueSupport}(::Type{Distribution{VF,VS}}) = VS
value_support{T<:Distribution}(::Type{T}) = value_support(super(T))

## TODO: the following types need to be improved
abstract SufficientStats
abstract IncompleteDistribution

typealias DistributionType{D<:Distribution} Type{D}
typealias IncompleteFormulation Union(DistributionType, IncompleteDistribution)

