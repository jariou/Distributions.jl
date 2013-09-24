using Distributions
using Base.Test


import Distributions.realmaxexp
import Distributions.realminexp

for t = [Float32, Float64, BigFloat]
    @test !isinf(exp(realmaxexp(t)))
    @test exp(realminexp(t)) != zero(t)    
end


import Distributions.log1mexp
import Distributions.log1pexp
import Distributions.logexpm1

import Distributions.logmxp1
import Distributions.log1pmx

import Distributions.lstirling




macro test_floatvsbig(a,fac)
    fargs = a.args[2:]
    b = Expr(:call,a.args[1],[:(big($u)) for u = fargs]...)
    stra = string(a)
    strb = string(b)
    argstr = :(string($([:(string($(string(u))," = ",$u,"::",typeof($u),", ")) for u in fargs]...)))
    quote
        va = $(esc(a))
        vb = oftype(va,$(esc(b)))
        diff = abs(va - vb)        
        maxeps = eps(max(abs(va),abs(vb)))
        if diff > $(esc(fac))*maxeps
            error("assertion failed: ",string("|",$stra," - ",$strb,"| <= ",$(string(fac))),"*eps",
                  "\n  ",$argstr,
                  "\n  ",$stra," = ",va,
                  "\n  ",$strb," = ",vb,
                  "\n  ","Relative error = ",diff/maxeps,"*eps")
        end                  
    end
end



# random mantissas
X = rand(10)+1.0


for x = X
    for t = [Float32, Float64]        
        # check across different orders of magnitude
        for i = exponent(realmin(t)):exponent(realmax(t))
            y = oftype(t,x*2.0^i)
            ny = -y
            @test_floatvsbig log1mexp(ny) 2
            @test_floatvsbig log1pexp(y) 2
            if !(0.5<y<1.0)
                # problem near log(2), e.g. 0.7066920197113992, 0.6946767369692368, 
                @test_floatvsbig logexpm1(y) 2
            end


            @test_floatvsbig logmxp1(y) 4

            # still slightly inaccurate for values just less than < -0.18
            # e.g. -0.18862401f0
            if y >= 1e-60   # BigFloat underflow
                @test_floatvsbig log1pmx(y) 8
                if ny > -1
                    @test_floatvsbig log1pmx(ny) 8
                end
            end

            if y >= 10 # currently only valid for this range
                if y < 1e28 # else BigFloat underflow
                    @test_floatvsbig lstirling(y) 2
                end
            end
        end
    end
end
