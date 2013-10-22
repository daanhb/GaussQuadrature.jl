module GaussQuadrature

# October 2013 by Bill McLean, School of Maths and Stats,
# The University of New South Wales.
#
# Based on earlier Fortran codes
#
# gaussq.f original version 20 Jan 1975 from Stanford
# gaussq.f modified 21 Dec by Eric Grosse
# gaussquad.f95 Nov 2005 by Bill Mclean
#
# This module provides functions to compute the abscissae x[j] and 
# weights w[j] for the classical Gauss quadrature rules, including 
# the Radau and Lobatto variants.  Thus, the sum
#
#           n
#          ---
#          \
#           |  w[j] f(x[j])
#          /
#          ---
#          j=1
#
# approximates
#
#          / hi
#          |
#          |    f(x) w(x) dx
#          |
#          / lo
#
# where the weight function w(x) and interval lo < x < hi are as shown
# in the table below.
#
# Name                      Interval     Weight Function
#
# Legendre                 -1 < x < 1          1      
# Chebyshev (first kind)   -1 < x < 1     1 / sqrt(1-x^2)        
# Chebyshev (second kind)  -1 < x < 1       sqrt(1-x^2)          
# Jacobi                   -1 < x < 1   (1-x)^alpha (1+x)^beta  
# Laguerre                 -1 < x < oo     x^alpha exp(-x)
# Hermite                 -oo < x < oo      exp(-x^2)
#
# For the Jacobi and Laguerre rules we require alpha > -1 and
# beta > -1, so that the weight function is integrable.
#
# Use the endpt argument to include one or both of the end points
# of the interval of integration as an abscissa in the the quadrature 
# rule, as follows.
# 
# endpt = neither   Default,     a < x[j] < b, j = 1:n.
# endpt = left      Left Radau,  a = x[1] < x[j] < b, j = 2:n.
# endpt = right     Right Radau, a < x[j] < x[n] = b, j = 1:n-1.
# endpt = both      Lobatto,     a = x[1] < x[j] < x[n] = b, j = 2:n-1.
#
# These labels make up an enumeration of type EndPt.
#
# The code uses the Golub and Welsch algorithm, in which the abscissae
# x[j] are the eigenvalues of a symmetric tridiagonal matrix whose 
# entries depend on the coefficients in the 3-term recurrence relation
# for the othonormal polynomials generated by the weighted inner product.
#
# References:
#
#   1.  Golub, G. H., and Welsch, J. H., Calculation of gaussian
#       quadrature rules, Mathematics of Computation 23 (april,
#       1969), pp. 221-230.
#   2.  Golub, G. H., Some modified matrix eigenvalue problems,
#       Siam Review 15 (april, 1973), pp. 318-334 (section 7).
#   3.  Stroud and Secrest, Gaussian Quadrature Formulas, Prentice-
#       Hall, Englewood Cliffs, N.J., 1966.

using Base

export neither, left, right, both
export legendre, legendre_coeff
export chebyshev, chebyshev_coeff
export jacobi, jacobi_coeff
export laguerre, laguerre_coeff 
export hermite, hermite_coeff
export custom_gauss_rule, orthonormal_poly

immutable EndPt
    label :: String
end

const neither = EndPt("NEITHER")
const left    = EndPt("LEFT")
const right   = EndPt("RIGHT")
const both    = EndPt("BOTH")

function legendre{T<:FloatingPoint}(n::Integer, endpt::EndPt=neither, 
                                    ::Type{T}=Float64)
    a, b, muzero = legendre_coeff(n, endpt, T)
    return custom_gauss_rule(-one(T), one(T), a, b, muzero, endpt)
end

function legendre_coeff{T<:FloatingPoint}(n::Integer, endpt::EndPt, 
                                          ::Type{T})
    muzero = convert(T, 2.0)
    a = zeros(T, n)
    b = zeros(T, n)
    for i = 1:n
        b[i] = i / sqrt(convert(T, 4*i^2-1))
    end
    return a, b, muzero
end

function chebyshev{T<:FloatingPoint}(n::Integer, kind::Integer=1, 
                            endpt::EndPt=neither, ::Type{T}=Float64)
    @assert kind in {1, 2}
    a, b, muzero = chebyshev_coeff(n, kind, endpt, T)
    return custom_gauss_rule(-one(T), one(T), a, b, muzero, endpt)
end

function chebyshev_coeff{T<:FloatingPoint}(n::Integer, kind::Integer, 
                                           endpt::EndPt, ::Type{T})
    muzero = convert(T, pi)
    half = convert(T, 0.5)
    a = zeros(T, n)
    b = fill(half, n)
    if kind == 1
        b[1] = sqrt(half)
    elseif kind == 2
        muzero /= 2
    else
        error("Unsupported value for kind")
    end
    return a, b, muzero
end

function jacobi{T<:FloatingPoint}(n::Integer, alpha::T, beta::T, 
                                  endpt::EndPt=neither)
    @assert alpha > -1.0 && beta > -1.0
    a, b, muzero = jacobi_coeff(n, alpha, beta, endpt)
    custom_gauss_rule(-one(T), one(T), a, b, muzero, endpt)
end

function jacobi_coeff{T<:FloatingPoint}(n::Integer, alpha::T, 
                                        beta::T, endpt::EndPt)
    ab = alpha + beta
    i = 2
    abi = ab + 2
    muzero = 2^(ab+1) * exp(
             lgamma(alpha+1) + lgamma(beta+1) - lgamma(abi) )
    a = zeros(T, n)
    b = zeros(T, n)
    a[1] = ( beta - alpha ) / abi
    b[1] = sqrt( 4*(alpha+1)*(beta+1) / ( (ab+3)*abi*abi ) )
    a2b2 = beta*beta - alpha*alpha
    for i = 2:n
        abi = ab + 2i
        a[i] = a2b2 / ( (abi-2)*abi )
        b[i] = sqrt( 4i*(alpha+i)*(beta+i)*(ab+i) /
                     ( (abi*abi-1)*abi*abi ) )
    end   
    return a, b, muzero
end

function laguerre{T<:FloatingPoint}(n::Integer, alpha::T=zero(T), 
                        endpt::EndPt=neither, ::Type{T}=Float64)
    @assert alpha > -1.0
    a, b, muzero = laguerre_coeff(n, alpha, endpt)
    custom_gauss_rule(zero(T), convert(T, Inf), a, b, muzero, endpt)
end

function laguerre_coeff{T<:FloatingPoint}(n::Integer, alpha::T, 
                                          endpt::EndPt)
    @assert endpt in {neither, left}
    muzero = gamma(alpha+1)
    a = zeros(T, n)
    b = zeros(T, n)
    for i = 1:n
        a[i] = 2i - 1 + alpha
        b[i] = sqrt( i*(alpha+i) )
    end
    return a, b, muzero
end

function hermite{T<:FloatingPoint}(n, ::Type{T}=Float64)
    a, b, muzero = hermite_coeff(n, T)
    custom_gauss_rule(convert(T, -Inf), convert(T, Inf), a, b, 
                      muzero, neither)
end

function hermite_coeff{T}(n::Integer, ::Type{T}=Float64)
    muzero = sqrt(convert(T, pi))
    a = zeros(T, n)
    b = zeros(T, n)
    for i = 1:n
        iT = convert(T, i)
        b[i] = sqrt(iT/2)
    end
    return a, b, muzero
end

function custom_gauss_rule{T<:FloatingPoint}(lo::T, hi::T, 
         a::Array{T,1}, b::Array{T,1}, muzero::T, endpt::EndPt)
    #
    # On entry:
    #
    # a, b hold the coefficients (as given, for instance, by
    # legendre_coeff!) in the three-term recurrence relation
    # for the orthonormal polynomials p_0, p_1, p_2, ... , that is,
    #
    #    b[j] p (x) = (x-a[j]) p   (x) - b[j-1] p   (x).
    #          j                j-1              j-2
    #      
    # muzero holds the zeroth moment of the weight function, that is
    #
    #              / hi
    #             |
    #    muzero = | w(x) dx.
    #             |
    #             / lo
    #
    # On return:
    #
    # x, w hold the points and weights.
    #
    n = length(a)
    @assert length(b) == n
    if endpt == left 
        if n == 1
            a[1] = lo
        else
            a[n] = solve(n, lo, a, b) * b[n-1]^2 + lo
        end
    elseif endpt == right
        if n == 1
            a[1] = hi
        else
            a[n] = solve(n, hi, a, b) * b[n-1]^2 + hi
        end
    elseif endpt == both
        if n == 1 
            error("Must have at least two points for both ends.")
        end 
        g = solve(n, lo, a, b)
        t1 = ( hi - lo ) / ( g - solve(n, hi, a, b) )
        b[n-1] = sqrt(t1)
        a[n] = lo + g * t1
    end
    A = SymTridiagonal(a, b[1:n-1])
    x, V = eig(A)
    w = zero(x)
    for i = 1:n
        w[i] = muzero * V[1,i]^2
    end
    return x, w
end

function solve(n, shift, a, b)
    #
    # Perform elimination to find the nth component s = delta[n]
    # of the solution to the nxn linear system
    #
    #     ( J_n - shift I_n ) delta = e_n,
    #
    # where J_n is the symmetric tridiagonal matrix with diagonal
    # entries a[i] and off-diagonal entries b[i], and e_n is the nth
    # standard basis vector.
    #
    t = a[1] - shift
    for i = 2:n-1
        t = a[i] - shift - b[i-1]^2 / t
    end
    return one(t) / t
end

function orthonormal_poly(x, a, b, muzero)
    # p[i,j] = value at x[i] of orthonormal polynomial of degree j-1.
    m = length(x)
    n = length(a)
    p = zeros(m,n+1)
    c = 1.0 / sqrt(muzero)
    rb = 1.0 / b[1]
    for i = 1:m
        p[i,1] = c
        p[i,2] = rb * ( x[i] - a[1] ) * c
    end 
    for j = 2:n
       rb = 1.0 / b[j]
       for i = 1:m
           p[i,j+1] = rb * ( (x[i]-a[j]) * p[i,j] 
                                - b[j-1] * p[i,j-1] )
       end
    end
    return p
end

end
