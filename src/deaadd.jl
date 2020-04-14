# This file contains functions for the Additive DEA model
"""
    AdditivelDEAModel
An data structure representing an additive DEA model.
"""
struct AdditiveDEAModel <: AbstractTechnicalDEAModel
    n::Int64
    m::Int64
    s::Int64
    weights::Symbol
    orient::Symbol
    rts::Symbol
    eff::Vector
    slackX::Matrix
    slackY::Matrix
    lambda::SparseMatrixCSC{Float64, Int64}

end

"""
    deaadd(X, Y, model)
Compute related data envelopment analysis weighted additive models for inputs `X` and outputs `Y`.

Model specification:
- `:Ones`: standard additive DEA model.
- `:MIP`: Measure of Inefficiency Proportions. (Charnes et al., 1987; Cooper et al., 1999)
- `:Normalized`: Normalized weighted additive DEA model. (Lovell and Pastor, 1995)
- `:RAM`: Range Adjusted Measure. (Cooper et al., 1999)
- `:BAM`: Bounded Adjusted Measure. (Cooper et al, 2011)
- `:Custom`: User supplied weights.

# Optional Arguments
- `orient=:Graph`: choose between graph oriented `:Graph`, input oriented `:Input`, or output oriented model `:Output`.
- `rts=:VRS`: choose between constant returns to scale `:CRS` or variable returns to scale `:VRS`.
- `wX`: matrix of weights of inputs. Only if `model=:Custom`.
- `WY`: matrix of weights of outputs. Only if `model=:Custom`.
- `Xref=X`: Identifies the reference set of inputs against which the units are evaluated.
- `Yref=Y`: Identifies the reference set of outputs against which the units are evaluated.
- `disposalX=:Strong`: chooses strong disposal of inputs. For weak disposal choose `:Weak`.
- `disposalY=:Strong`: chooses strong disposal of outputs. For weak disposal choose `:Weak`.

# Examples
```jldoctest
julia> X = [5 13; 16 12; 16 26; 17 15; 18 14; 23 6; 25 10; 27 22; 37 14; 42 25; 5 17];

julia> Y = [12; 14; 25; 26; 8; 9; 27; 30; 31; 26; 12];

julia> deaadd(X, Y, :MIP)
Weighted Additive DEA Model
DMUs = 11; Inputs = 2; Outputs = 1
Orientation = Graph; Returns to Scale = VRS
Weights = MIP
─────────────────────────────────────────────────────
      efficiency       slackX1  slackX2       slackY1
─────────────────────────────────────────────────────
1    0.0           0.0              0.0   0.0
2    0.507519      0.0              0.0   7.10526
3    0.0           0.0              0.0   0.0
4   -4.72586e-17  -8.03397e-16      0.0   0.0
5    2.20395       0.0              0.0  17.6316
6    1.31279e-16   8.10382e-16      0.0   8.64407e-16
7    0.0           0.0              0.0   0.0
8    0.0           0.0              0.0   0.0
9    0.0           0.0              0.0   0.0
10   1.04322      17.0             15.0   1.0
11   0.235294      0.0              4.0   0.0
─────────────────────────────────────────────────────
```
"""
function deaadd(X::Matrix, Y::Matrix, model::Symbol = :Default; orient::Symbol = :Graph,
    rts::Symbol = :VRS,
    wX::Matrix = Array{Float64}(undef, 0, 0), wY::Matrix = Array{Float64}(undef, 0, 0),
    Xref::Matrix = X, Yref::Matrix = Y,
    disposalX::Symbol = :Strong, disposalY::Symbol = :Strong)::AdditiveDEAModel

    # Check parameters
    nx, m = size(X)
    ny, s = size(Y)

    nrefx, mref = size(Xref)
    nrefy, sref = size(Yref)

    if nx != ny
        error("number of observations is different in inputs and outputs")
    end
    if nrefx != nrefy
        error("number of observations is different in inputs reference set and ouputs reference set")
    end
    if m != mref
        error("number of inputs in evaluation set and reference set is different")
    end
    if s != sref
        error("number of outputs in evaluation set and reference set is different")
    end

    if disposalX != :Strong && disposalX != :Weak
        error("Invalid inputs disposal $disposalX. Disposal should be :Strong or :Weak")
    end
    if disposalY != :Strong && disposalY != :Weak
        error("Invalid outputs disposal $disposalY. Disposal should be :Strong or :Weak")
    end

    if orient == :Input && disposalX == :Weak
        error("Weak input disposal not possible in input oriented model")
    end
    if orient == :Output && disposalY == :Weak
        error("Weak output disposal not possible in output oriented model")
    end
    if orient == :Graph && (disposalX == :Weak || disposalY == :Weak)
        error("Weak disposal not possible in graph oriented model")
    end

    # Default behaviour
    if model == :Default
        # If no weights are specified use :Ones
        if length(wX) == 0 && length(wY) == 0
            model = :Ones
        else
            model = :Custom
        end
    end

    # Get weights based on the selected model
    if model != :Custom
        # Display error if both model and weights are specified
        if length(wX) != 0 || length(wY) != 0
            error("Weights not allowed if model != :Custom")
        end

        # Get weights for selected model
        wX, wY = deaaddweights(X, Y, model, orient = orient)
    end

    if size(wX) != size(X)
        error("size of weights matrix for inputs should be equal to size of inputs")
    end
    if size(wY) != size(Y)
        error("size of weights matrix for outputs should be qual to size of outputs")
    end

    # Parameters for additional condition in BAM model
    minXref = minimum(X, dims = 1)
    maxYref = maximum(Y, dims = 1)

    # Compute efficiency for each DMU
    n = nx
    nref = nrefx

    effi = zeros(n)
    slackX = zeros(n, m)
    slackY = zeros(n, s)
    lambdaeff = spzeros(n, nref)

    for i=1:n
        # Value of inputs and outputs to evaluate
        x0 = X[i,:]
        y0 = Y[i,:]

        # Value of weights to evaluate
        wX0 = wX[i,:]
        wY0 = wY[i,:]

        # Set weights to zero if Weak disposal
        if disposalX == :Weak
            wX0 = zeros(1, n)
        end

        if disposalY == :Weak
            wY0 = zeros(1, n)
        end

        # Create the optimization model
        deamodel = Model(GLPK.Optimizer)

        @variable(deamodel, sX[1:m] >= 0)
        @variable(deamodel, sY[1:s] >= 0)
        @variable(deamodel, lambda[1:nref] >= 0)

        if orient == :Graph
            @objective(deamodel, Max, sum(wX0[j] * sX[j] for j in 1:m) + sum(wY0[j] * sY[j] for j in 1:s) )
        elseif orient == :Input
            @objective(deamodel, Max, sum(wX0[j] * sX[j] for j in 1:m)  )
        elseif orient == :Output
            @objective(deamodel, Max, sum(wY0[j] * sY[j] for j in 1:s) )
        else
            error("Invalid orientation $orient. Orientation should be :Graph, :Input or :Output")
        end

        @constraint(deamodel, [j in 1:m], sum(Xref[t,j] * lambda[t] for t in 1:nref) == x0[j] - sX[j])
        @constraint(deamodel, [j in 1:s], sum(Yref[t,j] * lambda[t] for t in 1:nref) == y0[j] + sY[j])

        # Add return to scale constraints
        if rts == :CRS
            # Add constraints for BAM CRS model
            if model == :BAM
                @constraint(deamodel, [j in 1:m], sum(Xref[t,j] * lambda[t] for t in 1:nref) >= minXref[j])
                @constraint(deamodel, [j in 1:s], sum(Yref[t,j] * lambda[t] for t in 1:nref) <= maxYref[j])
            end
        elseif rts == :VRS
            @constraint(deamodel, sum(lambda) == 1)
        else
            error("Invalid returns to scale $rts. Returns to scale should be :CRS or :VRS")
        end

        # Fix values of slacks when weight are zero
        for j = 1:m
            if wX0[j] == 0
                fix(sX[j], 0, force = true)
            end
        end

        for j = 1:s
            if wY0[j] == 0
                fix(sY[j], 0, force = true)
            end
        end

        # Optimize and return results
        JuMP.optimize!(deamodel)

        effi[i]  = JuMP.objective_value(deamodel)
        lambdaeff[i,:] = JuMP.value.(lambda)

        slackX[i,:] = JuMP.value.(sX)
        slackY[i,:] = JuMP.value.(sY)

        # Check termination status
        if termination_status(deamodel) != MOI.OPTIMAL
            @warn ("DMU $i termination status: $(termination_status(deamodel)). Primal status: $(primal_status(deamodel)). Dual status: $(dual_status(deamodel))")
        end

    end

    return AdditiveDEAModel(n, m, s, model, orient, rts, effi, slackX, slackY, lambdaeff)

end

function deaadd(X::Vector, Y::Matrix, model::Symbol = :Default; orient::Symbol = :Graph,
    rts::Symbol = :VRS,
    wX::Vector = Array{Float64}(undef, 0), wY::Matrix = Array{Float64}(undef, 0, 0),
    Xref::Vector = X, Yref::Matrix = Y,
    disposalX::Symbol = :Strong, disposalY::Symbol = :Strong)::AdditiveDEAModel

    X = X[:,:]
    wX = wX[:,:]
    Xref = Xref[:,:]
    return deaadd(X, Y, model, orient = orient, rts = rts, wX = wX, wY = wY, Xref = Xref, Yref = Yref, disposalX = disposalX, disposalY = disposalY)
end

function deaadd(X::Matrix, Y::Vector, model::Symbol = :Default; orient::Symbol = :Graph,
    rts::Symbol = :VRS,
    wX::Matrix = Array{Float64}(undef, 0, 0), wY::Vector = Array{Float64}(undef, 0),
    Xref::Matrix = X, Yref::Vector = Y,
    disposalX::Symbol = :Strong, disposalY::Symbol = :Strong)::AdditiveDEAModel

    Y = Y[:,:]
    wY = wY[:,:]
    Yref = Yref[:,:]
    return deaadd(X, Y, model, orient = orient, rts = rts, wX = wX, wY = wY, Xref = Xref, Yref = Yref, disposalX = disposalX, disposalY = disposalY)
end

function deaadd(X::Vector, Y::Vector, model::Symbol = :Default; orient::Symbol = :Graph,
    rts::Symbol = :VRS,
    wX::Vector = Array{Float64}(undef, 0), wY::Vector = Array{Float64}(undef, 0),
    Xref::Vector = X, Yref::Vector = Y,
    disposalX::Symbol = :Strong, disposalY::Symbol = :Strong)::AdditiveDEAModel

    X = X[:,:]
    wX = wX[:,:]
    Xref = Xref[:,:]
    Y = Y[:,:]
    wY = wY[:,:]
    Yref = Yref[:,:]
    return deaadd(X, Y, model, orient = orient, rts = rts, wX = wX, wY = wY, Xref = Xref, Yref = Yref, disposalX = disposalX, disposalY = disposalY)
end

function Base.show(io::IO, x::AdditiveDEAModel)
    compact = get(io, :compact, false)

    n = nobs(x)
    m = ninputs(x)
    s = noutputs(x)
    eff = efficiency(x)
    slackX = slacks(x, :X)
    slackY = slacks(x, :Y)

    if !compact
        print(io, "Weighted Additive DEA Model \n")
        print(io, "DMUs = ", n)
        print(io, "; Inputs = ", m)
        print(io, "; Outputs = ", s)
        print(io, "\n")
        print(io, "Orientation = ", string(x.orient))
        print(io, "; Returns to Scale = ", string(x.rts))
        print(io, "\n")
        print(io, "Weights = ", string(x.weights))
        print(io, "\n")
        show(io, CoefTable(hcat(eff, slackX, slackY), ["efficiency"; ["slackX$i" for i in 1:m ]; ; ["slackY$i" for i in 1:s ]], ["$i" for i in 1:n]))
    end

end

"""
    deaaddweights(X, Y, model)
Compute corresponding weights for related data envelopment analysis weighted additive models for inputs `X` and outputs `Y`.

Model specification:
- `:Ones`: standard additive DEA model.
- `:MIP`: Measure of Inefficiency Proportions. (Charnes et al., 1987; Cooper et al., 1999)
- `:Normalized`: Normalized weighted additive DEA model. (Lovell and Pastor, 1995)
- `:RAM`: Range Adjusted Measure. (Cooper et al., 1999)
- `:BAM`: Bounded Adjusted Measure. (Cooper et al, 2011)

# Optional Arguments
- `orient=:Graph`: choose between graph oriented `:Graph`, input oriented `:Input`, or output oriented model `:Output`.

"""
function deaaddweights(X::Matrix, Y::Matrix, model::Symbol; orient::Symbol = :Graph)

    # Check orientation
    if orient != :Graph && orient != :Input && orient != :Output
        error("Invalid orientation $orient. Orientation should be :Graph, :Input or :Output")
    end

    # Compute specific weights based on the model
    if model == :Ones
        # Standard Additive DEA model
        if orient == :Graph || orient == :Input
            wX = ones(size(X))
        end
        if orient == :Graph || orient == :Output
            wY = ones(size(Y))
        end

    elseif model == :MIP
        # Measure of Inefficiency Proportions
        if orient == :Graph || orient == :Input
            wX = 1 ./ X
        end
        if orient == :Graph || orient == :Output
            wY = 1 ./ Y
        end

    elseif model == :Normalized
        # Normalized weighted additive DEA model
        if orient == :Graph || orient == :Input

            wX = zeros(size(X))
            m = size(X, 2)

            for i=1:m
                wX[:,i] .= 1 ./ std(X[:,i])
            end

            wX[isinf.(wX)] .= 0
        end
        if orient == :Graph || orient == :Output

            wY = zeros(size(Y))
            s = size(Y, 2)

            for i=1:s
                wY[:,i] .= 1 ./ std(Y[:,i])
            end

            wY[isinf.(wY)] .= 0
        end

    elseif model == :RAM
        # Range Adjusted Measure
        m = size(X, 2)
        s = size(Y, 2)

        normalization = 0
        if orient == :Graph
            normalization = m + s
        elseif orient == :Input
            normalization = m
        elseif orient == :Output
            normalization = s
        end

        if orient == :Graph || orient == :Input

            wX = zeros(size(X))

            for i=1:m
                wX[:,i] .= 1 ./ (normalization * (maximum(X[:,i])  - minimum(X[:,i])))
            end

            wX[isinf.(wX)] .= 0
        end
        if orient == :Graph || orient == :Output

            wY = zeros(size(Y))

            for i=1:s
                wY[:,i] .= 1 ./ (normalization * (maximum(Y[:,i])  - minimum(Y[:,i])))
            end

            wY[isinf.(wY)] .= 0
        end

    elseif model == :BAM
        # Bounded Adjusted Measure
        m = size(X, 2)
        s = size(Y, 2)

        normalization = 0
        if orient == :Graph
            normalization = m + s
        elseif orient == :Input
            normalization = m
        elseif orient == :Output
            normalization = s
        end

        if orient == :Graph || orient == :Input

            wX = zeros(size(X))
            minX = zeros(m)

            for i=1:m
                minX[i] = minimum(X[:,i])
                wX[:,i] = 1 ./ (normalization .* (X[:,i] .- minX[i] ))
            end

            wX[isinf.(wX)] .= 0
        end
        if orient == :Graph || orient == :Output

            wY = zeros(size(Y))
            maxY = zeros(s)

            for i=1:s
                maxY[i] = maximum(Y[:,i])
                wY[:,i] = 1 ./ (normalization .* (maxY[i] .- Y[:,i]))
            end

            wY[isinf.(wY)] .= 0
        end

    else
        error("Invalid model ", model)
    end

    if orient == :Input
        wY = ones(size(Y))
    elseif orient == :Output
        wX = ones(size(X))
    end

    return wX, wY

end