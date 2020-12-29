# This file contains functions for the Profit Efficiency DEA model
"""
    ProfitDEAModel
An data structure representing a profit DEA model.
"""
struct ProfitDEAModel <: AbstractProfitDEAModel
    n::Int64
    m::Int64
    s::Int64
    Gx::Symbol
    Gy::Symbol
    dmunames::Union{Vector{String},Nothing}
    eff::Vector
    lambda::SparseMatrixCSC{Float64, Int64}
    techeff::Vector
    alloceff::Vector
    Xtarget::Matrix
    Ytarget::Matrix
end


"""
    deaprofit(X, Y, W, P; Gx, Gy)
Compute profit efficiency using data envelopment analysis model for
inputs `X`, outputs `Y`, price of inputs `W`, and price of outputs `P`.

# Direction specification:

The directions `Gx` and `Gy` can be one of the following symbols.
- `:Zeros`: use zeros.
- `:Ones`: use ones.
- `:Observed`: use observed values.
- `:Mean`: use column means.
- `:Monetary`: use direction so that profit inefficiency is expressed in monetary values.

Alternatively, a vector or matrix with the desired directions can be supplied.

# Optional Arguments
- `names`: a vector of strings with the names of the decision making units.

# Examples
```jldoctest
julia> X = [1 1; 1 1; 0.75 1.5; 0.5 2; 0.5 2; 2 2; 2.75 3.5; 1.375 1.75];

julia> Y = [1 11; 5 3; 5 5; 2 9; 4 5; 4 2; 3 3; 4.5 3.5];

julia> P = [2 1; 2 1; 2 1; 2 1; 2 1; 2 1; 2 1; 2 1];

julia> W = [2 1; 2 1; 2 1; 2 1; 2 1; 2 1; 2 1; 2 1];

julia> deaprofit(X, Y, W, P, Gx = :Monetary, Gy = :Monetary)
Profit DEA Model
DMUs = 8; Inputs = 2; Outputs = 2
Returns to Scale = VRS
─────────────────────────────────────
   Profit     Technical    Allocative
─────────────────────────────────────
1     2.0   0.0           2.0
2     2.0  -5.41234e-16   2.0
3     0.0   0.0           0.0
4     2.0   0.0           2.0
5     2.0   0.0           2.0
6     8.0   6.0           2.0
7    12.0  12.0          -1.77636e-15
8     4.0   3.0           1.0
─────────────────────────────────────
```
"""
function deaprofit(X::Union{Matrix,Vector}, Y::Union{Matrix,Vector},
    W::Union{Matrix,Vector}, P::Union{Matrix,Vector};
    Gx::Union{Symbol,Matrix,Vector}, Gy::Union{Symbol,Matrix,Vector},
    names::Union{Vector{String},Nothing} = nothing)::ProfitDEAModel

    # Check parameters
    nx, m = size(X, 1), size(X, 2)
    ny, s = size(Y, 1), size(Y, 2)

    nw, mw = size(W, 1), size(W, 2)
    np, sp = size(P, 1), size(P, 2)

    if nx != ny
        error("number of observations is different in inputs and outputs")
    end
    if nw != nx
        error("number of observations is different in input prices and inputs")
    end
    if np != ny
        error("number of observations is different in output prices and outputs")
    end
    if mw != m
        error("number of input prices and intputs is different")
    end
    if sp != s
        error("number of output prices and outputs is different")
    end

    # Build or get user directions
    if typeof(Gx) == Symbol
        Gxsym = Gx

        if Gx == :Zeros
            Gx = zeros(size(X))
        elseif Gx == :Ones
            Gx = ones(size(X))
        elseif Gx == :Observed
            Gx = X
        elseif Gx == :Mean
            Gx = repeat(mean(X, dims = 1), size(X, 1))
        elseif Gx == :Monetary
            GxGydollar = 1 ./ (sum(P, dims = 2) + sum(W, dims = 2));
            Gx = repeat(GxGydollar, 1, m);
        else
            error("Invalid inputs direction")
        end

    else
        Gxsym = :Custom
    end

    if typeof(Gy) == Symbol
        Gysym = Gy

        if Gy == :Zeros
            Gy = zeros(size(Y))
        elseif Gy == :Ones
            Gy = ones(size(Y))
        elseif Gy == :Observed
            Gy = Y
        elseif Gy == :Mean
            Gy = repeat(mean(Y, dims = 1), size(Y, 1))
        elseif Gy == :Monetary
            GxGydollar = 1 ./ (sum(P, dims = 2) + sum(W, dims = 2));
            Gy = repeat(GxGydollar, 1, s);
        else
            error("Invalid outputs direction")
        end

    else
        Gysym = :Custom
    end

    if (size(Gx, 1) != size(X, 1)) | (size(Gx, 2) != size(X, 2))
        error("size of inputs should be equal to size of inputs direction")
    end
    if (size(Gy, 1) != size(Y, 1)) | (size(Gy, 2) != size(Y, 2))
        error("size of outputs should be equal to size of outputs direction")
    end

    # Compute efficiency for each DMU
    n = nx

    Xtarget = zeros(n,m)
    Ytarget = zeros(n,s)
    pefficiency = zeros(n)
    plambdaeff = spzeros(n, n)

    for i=1:n
        # Value of inputs and outputs to evaluate
        w0 = W[i,:]
        p0 = P[i,:]

        # Create the optimization model
        deamodel = Model(GLPK.Optimizer)

        @variable(deamodel, Xeff[1:m])
        @variable(deamodel, Yeff[1:s])
        @variable(deamodel, lambda[1:n] >= 0)

        @objective(deamodel, Max, (sum(p0[j] .* Yeff[j] for j in 1:s)) - (sum(w0[j] .* Xeff[j] for j in 1:m)))

        @constraint(deamodel, [j in 1:m], sum(X[t,j] * lambda[t] for t in 1:n) <= Xeff[j])
        @constraint(deamodel, [j in 1:s], sum(Y[t,j] * lambda[t] for t in 1:n) >= Yeff[j])

        @constraint(deamodel, sum(lambda) == 1)

        # Optimize and return results
        JuMP.optimize!(deamodel)

        Xtarget[i,:]  = JuMP.value.(Xeff)
        Ytarget[i,:]  = JuMP.value.(Yeff)
        plambdaeff[i,:] = JuMP.value.(lambda)

        # Check termination status
        if termination_status(deamodel) != MOI.OPTIMAL
            @warn ("DMU $i termination status: $(termination_status(deamodel)). Primal status: $(primal_status(deamodel)). Dual status: $(dual_status(deamodel))")
        end

    end

    # Profit, technical and allocative efficiency
    maxprofit = sum(P .* Ytarget, dims = 2) .- sum(W .* Xtarget, dims = 2)

    pefficiency_num  = maxprofit .- ( sum(P .* Y, dims = 2) .- sum(W .* X, dims = 2))
    pefficiency_den = sum(P .* Gy, dims = 2) .+ sum(W .* Gx, dims = 2)
    pefficiency = vec( pefficiency_num ./ pefficiency_den )

    techefficiency = efficiency(deaddf(X, Y, Gx = Gx, Gy = Gy, rts = :VRS, slack = false))
    allocefficiency = pefficiency - techefficiency

    return ProfitDEAModel(n, m, s, Gxsym, Gysym, names, pefficiency, plambdaeff, techefficiency, allocefficiency, Xtarget, Ytarget)

end

function Base.show(io::IO, x::ProfitDEAModel)
    compact = get(io, :compact, false)

    n = nobs(x)
    m = ninputs(x)
    s = noutputs(x)
    dmunames = names(x)

    eff = efficiency(x)
    techeff = efficiency(x, :Technical)
    alloceff = efficiency(x, :Allocative)

    if !compact
        print(io, "Profit DEA Model \n")
        print(io, "DMUs = ", n)
        print(io, "; Inputs = ", m)
        print(io, "; Outputs = ", s)
        print(io, "\n")
        print(io, "Returns to Scale = VRS")
        print(io, "\n")
        print(io, "Gx = ", string(x.Gx), "; Gy = ", string(x.Gy))
        print(io, "\n")
        show(io, CoefTable(hcat(eff, techeff, alloceff), ["Profit", "Technical", "Allocative"], dmunames))
    end

end