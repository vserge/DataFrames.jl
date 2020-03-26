module TestDeprecated

using Test, DataFrames, Random, Logging

const ≅ = isequal

old_logger = global_logger(NullLogger())

# old sort(df; cols=...) syntax
df = DataFrame(a=[1, 3, 2], b=[6, 5, 4])
@test sort(df; cols=[:a, :b]) == DataFrame(a=[1, 2, 3], b=[6, 4, 5])
sort!(df; cols=[:a, :b])
@test df == DataFrame(a=[1, 2, 3], b=[6, 4, 5])

df = DataFrame(a=[1, 3, 2], b=[6, 5, 4])
@test sort(df; cols=[:b, :a]) == DataFrame(a=[2, 3, 1], b=[4, 5, 6])
sort!(df; cols=[:b, :a])
@test df == DataFrame(a=[2, 3, 1], b=[4, 5, 6])

@test first.(collect(pairs(DataFrameRow(df, 1, :)))) == [:a, :b]
@test last.(collect(pairs(DataFrameRow(df, 1, :)))) == [df[1, 1], df[1, 2]]

# deprecated combine

df = DataFrame(a=[1, 1, 2, 2, 2], b=1:5)
gd = groupby(df, :a)
@test combine(gd) == combine(identity, gd)

@testset "categorical constructor" begin
    df = DataFrame([Int, String], [:a, :b], [false, true], 3)
    @test !(df[:a] isa CategoricalVector)
    @test df[:b] isa CategoricalVector
    @test_throws DimensionMismatch DataFrame([Int, String], [:a, :b], [true], 3)
end

@testset "DataFrame constructors" begin
    df = DataFrame(Union{Int, Missing}, 10, 3)
    @test size(df, 1) == 10
    @test size(df, 2) == 3
    @test typeof(df[1]) == Vector{Union{Int, Missing}}
    @test typeof(df[2]) == Vector{Union{Int, Missing}}
    @test typeof(df[3]) == Vector{Union{Int, Missing}}
    @test all(ismissing, df[1])
    @test all(ismissing, df[2])
    @test all(ismissing, df[3])
    @test typeof(df[:, 1]) == Vector{Union{Int, Missing}}
    @test typeof(df[:, 2]) == Vector{Union{Int, Missing}}
    @test typeof(df[:, 3]) == Vector{Union{Int, Missing}}
    @test all(ismissing, df[:, 1])
    @test all(ismissing, df[:, 2])
    @test all(ismissing, df[:, 3])

    df = DataFrame([Union{Int, Missing}, Union{Float64, Missing}, Union{String, Missing}], 100)
    @test size(df, 1) == 100
    @test size(df, 2) == 3
    @test typeof(df[1]) == Vector{Union{Int, Missing}}
    @test typeof(df[2]) == Vector{Union{Float64, Missing}}
    @test typeof(df[3]) == Vector{Union{String, Missing}}
    @test all(ismissing, df[1])
    @test all(ismissing, df[2])
    @test all(ismissing, df[3])
    @test typeof(df[:, 1]) == Vector{Union{Int, Missing}}
    @test typeof(df[:, 2]) == Vector{Union{Float64, Missing}}
    @test typeof(df[:, 3]) == Vector{Union{String, Missing}}
    @test all(ismissing, df[:, 1])
    @test all(ismissing, df[:, 2])
    @test all(ismissing, df[:, 3])

    df = DataFrame([Union{Int, Missing}, Union{Float64, Missing}, Union{String, Missing}],
                [:A, :B, :C], [false, false, true], 100)
    @test size(df, 1) == 100
    @test size(df, 2) == 3
    @test typeof(df[1]) == Vector{Union{Int, Missing}}
    @test typeof(df[2]) == Vector{Union{Float64, Missing}}
    @test typeof(df[3]) <: CategoricalVector{Union{String, Missing}}
    @test all(ismissing, df[1])
    @test all(ismissing, df[2])
    @test all(ismissing, df[3])
    @test typeof(df[:, 1]) == Vector{Union{Int, Missing}}
    @test typeof(df[:, 2]) == Vector{Union{Float64, Missing}}
    @test typeof(df[:, 3]) <: CategoricalVector{Union{String, Missing}}
    @test all(ismissing, df[:, 1])
    @test all(ismissing, df[:, 2])
    @test all(ismissing, df[:, 3])
end

df = DataFrame(Union{Int, Missing}, 2, 2)
@test size(df) == (2, 2)
@test eltype.(eachcol(df)) == [Union{Int, Missing}, Union{Int, Missing}]

@test df ≅ DataFrame([Union{Int, Missing}, Union{Float64, Missing}], 2)

@testset "colwise" begin
    Random.seed!(1)
    df = DataFrame(a = repeat(Union{Int, Missing}[1, 3, 2, 4], outer=[2]),
                   b = repeat(Union{Int, Missing}[2, 1], outer=[4]),
                   c = Vector{Union{Float64, Missing}}(randn(8)))

    missingfree = DataFrame([collect(1:10)], [:x1])

    @testset "::Function, ::AbstractDataFrame" begin
        cw = colwise(sum, df)
        answer = [20, 12, -0.4283098098931877]
        @test isa(cw, Vector{Real})
        @test size(cw) == (ncol(df),)
        @test cw == answer

        cw = colwise(sum, missingfree)
        answer = [55]
        @test isa(cw, Array{Int, 1})
        @test size(cw) == (ncol(missingfree),)
        @test cw == answer
    end

    @testset "::Function, ::GroupedDataFrame" begin
        gd = groupby(DataFrame(A = [:A, :A, :B, :B], B = 1:4), :A)
        @test colwise(length, gd) == [[2,2], [2,2]]
    end

    @testset "::Vector, ::AbstractDataFrame" begin
        cw = colwise([sum], df)
        answer = [20 12 -0.4283098098931877]
        @test isa(cw, Array{Real, 2})
        @test size(cw) == (length([sum]),ncol(df))
        @test cw == answer

        cw = colwise([sum, minimum], missingfree)
        answer = reshape([55, 1], (2,1))
        @test isa(cw, Array{Int, 2})
        @test size(cw) == (length([sum, minimum]), ncol(missingfree))
        @test cw == answer

        cw = colwise([Vector{Union{Int, Missing}}], missingfree)
        answer = reshape([Vector{Union{Int, Missing}}(1:10)], (1,1))
        @test isa(cw, Array{Vector{Union{Int, Missing}},2})
        @test size(cw) == (1, ncol(missingfree))
        @test cw == answer

        @test_throws MethodError colwise(["Bob", :Susie], DataFrame(A = 1:10, B = 11:20))
    end

    @testset "::Vector, ::GroupedDataFrame" begin
        gd = groupby(DataFrame(A = [:A, :A, :B, :B], B = 1:4), :A)
        @test colwise([length], gd) == [[2 2], [2 2]]
    end

    @testset "::Tuple, ::AbstractDataFrame" begin
        cw = colwise((sum, length), df)
        answer = Any[20 12 -0.4283098098931877; 8 8 8]
        @test isa(cw, Array{Real, 2})
        @test size(cw) == (length((sum, length)), ncol(df))
        @test cw == answer

        cw = colwise((sum, length), missingfree)
        answer = reshape([55, 10], (2,1))
        @test isa(cw, Array{Int, 2})
        @test size(cw) == (length((sum, length)), ncol(missingfree))
        @test cw == answer

        cw = colwise((CategoricalArray, Vector{Union{Int, Missing}}), missingfree)
        answer = reshape([CategoricalArray(1:10), Vector{Union{Int, Missing}}(1:10)],
                         (2, ncol(missingfree)))
        @test typeof(cw) == Array{AbstractVector,2}
        @test size(cw) == (2, ncol(missingfree))
        @test cw == answer

        @test_throws MethodError colwise(("Bob", :Susie), DataFrame(A = 1:10, B = 11:20))
    end

    @testset "::Tuple, ::GroupedDataFrame" begin
        gd = groupby(DataFrame(A = [:A, :A, :B, :B], B = 1:4), :A)
        @test colwise((length), gd) == [[2,2],[2,2]]
    end
end

@testset "empty!" begin
    df = DataFrame(a=[1, 2], b=[3.0, 4.0])
    @test !isempty(df)

    dfv = view(df, 1:2, 1:2)

    @test empty!(df) === df
    @test isempty(eachcol(df))
    @test isempty(df)
    @test isempty(DataFrame(a=[], b=[]))
end

@testset "deletecols and deletecols!" begin
    df = DataFrame(a=[1,2], b=[3.0, 4.0])
    @test deletecols(df, :a) == DataFrame(b=[3.0, 4.0])
    deletecols!(df, :a)
    @test df == DataFrame(b=[3.0, 4.0])

    df = DataFrame(a=[1,2], b=[3.0, 4.0])
    @test deletecols(df, Not(2)) == DataFrame(b=[3.0, 4.0])
    deletecols!(df, Not(2))
    @test df == DataFrame(b=[3.0, 4.0])

    df = DataFrame(a=[1,2], b=[3.0, 4.0])
    @test deletecols(df, :a, copycols=false)[1] === df.b
    @test deletecols(df, []) == df
    @test deletecols(df, Not([])) == DataFrame()
end

@testset "haskey" begin
    df = DataFrame(x=1:3)
    @test haskey(df, 1)
    @test !haskey(DataFrame(), 1)
    @test !haskey(df, 2)
    @test !haskey(df, 0)
    @test haskey(df, :x)
    @test !haskey(df, :a)
    @test !haskey(df, "a")
end

@testset "df[col] and df[col] for getindex, view, and setindex" begin
    @testset "getindex DataFrame" begin
        df = DataFrame(a=1:3, b=4:6, c=7:9)
        @test df[1] == [1, 2, 3]
        @test df[1] === eachcol(df)[1]
        @test df[1:2] == DataFrame(a=1:3, b=4:6)
        @test df[r"[ab]"] == DataFrame(a=1:3, b=4:6)
        @test df[Not(Not(r"[ab]"))] == DataFrame(a=1:3, b=4:6)
        @test df[Not(3)] == DataFrame(a=1:3, b=4:6)
        @test eachcol(df)[1] === df[1]
        @test eachcol(view(df,1:2))[1] == eachcol(df)[1]
        @test eachcol(df[1:2])[1] == eachcol(df)[1]
        @test eachcol(df[r"[ab]"])[1] == eachcol(df)[1]
        @test eachcol(df[Not(Not(r"[ab]"))])[1] == eachcol(df)[1]
        @test eachcol(df[Not(r"[c]")])[1] == eachcol(df)[1]
        @test eachcol(df[1:2])[1] !== eachcol(df)[1]
        @test df[:] == df
        @test df[r""] == df
        @test df[Not(Not(r""))] == df
        @test df[Not(1:0)] == df
        @test df[:] !== df
        @test df[r""] !== df
        @test df[Not(Not(r""))] !== df
        @test df[Not(1:0)] !== df
        @test eachcol(view(df, :))[1] == eachcol(df)[1]
        @test eachcol(df[:])[1] == eachcol(df)[1]
        @test eachcol(df[r""])[1] == eachcol(df)[1]
        @test eachcol(df[Not(1:0)])[1] == eachcol(df)[1]
        @test eachcol(df[:])[1] !== eachcol(df)[1]
        @test eachcol(df[r""])[1] !== eachcol(df)[1]
        @test eachcol(df[Not(1:0)])[1] !== eachcol(df)[1]
    end
    @testset "getindex df[col] and df[cols]" begin
        x = [1, 2, 3]
        df = DataFrame(x=x, copycols=false)
        @test df[:x] === x
        @test df[[:x]].x !== x
        @test df[:].x !== x
        @test df[r"x"].x !== x
        @test df[r""].x !== x
        @test df[Not(1:0)].x !== x
    end
    @testset "view DataFrame" begin
        df = DataFrame(a=1:3, b=4:6, c=7:9)
        @test view(df, 1) == [1, 2, 3]
        @test view(df, 1) isa SubArray
        @test view(df, 1:2) isa SubDataFrame
        @test view(df, 1:2) == df[1:2]
        @test view(df, r"[ab]") isa SubDataFrame
        @test view(df, r"[ab]") == df[1:2]
        @test view(df, Not(Not(r"[ab]"))) isa SubDataFrame
        @test view(df, Not(Not(r"[ab]"))) == df[1:2]
        @test view(df, :) isa SubDataFrame
        @test view(df, :) == df
        @test parent(view(df, :)) === df
        @test view(df, r"") isa SubDataFrame
        @test view(df, r"") == df
        @test parent(view(df, r"")) === df
        @test view(df, Not(1:0)) isa SubDataFrame
        @test view(df, Not(1:0)) == df
        @test parent(view(df, Not(1:0))) === df
    end
    @testset "getindex SubDataFrame" begin
        df = DataFrame(x=-1:3, a=0:4, b=3:7, c=6:10, d=9:13)
        sdf = view(df, 2:4, 2:4)
        @test sdf[1] == [1, 2, 3]
        @test sdf[1] isa SubArray
        @test sdf[1:2] == DataFrame(a=1:3, b=4:6)
        @test sdf[1:2] isa SubDataFrame
        @test sdf[r"[ab]"] == DataFrame(a=1:3, b=4:6)
        @test sdf[r"[ab]"] isa SubDataFrame
        @test sdf[Not(Not(r"[ab]"))] == DataFrame(a=1:3, b=4:6)
        @test sdf[Not(Not(r"[ab]"))] isa SubDataFrame
        @test sdf[:] == df[2:4, 2:4]
        @test sdf[:] isa SubDataFrame
        @test sdf[r""] == df[2:4, 2:4]
        @test sdf[r""] isa SubDataFrame
        @test sdf[Not(1:0)] == df[2:4, 2:4]
        @test sdf[Not(1:0)] isa SubDataFrame
        @test parent(sdf[:]) === parent(sdf)
        @test parent(sdf[r""]) === parent(sdf)
        @test parent(sdf[Not([])]) === parent(sdf)
    end
    @testset "view SubDataFrame" begin
        df = DataFrame(x=-1:3, a=0:4, b=3:7, c=6:10, d=9:13)
        sdf = view(df, 2:4, 2:4)
        @test view(sdf, 1) == [1, 2, 3]
        @test view(sdf, 1) isa SubArray
        @test view(sdf, 1:2) isa SubDataFrame
        @test view(sdf, 2:3) == df[2:4, 3:4]
        @test view(sdf, r"[ab]") isa SubDataFrame
        @test view(sdf, r"[ab]") == df[2:4, r"[ab]"]
        @test view(sdf, Not(Not(r"[ab]"))) isa SubDataFrame
        @test view(sdf, Not(Not(r"[ab]"))) == df[2:4, Not(Not(r"[ab]"))]
        @test view(sdf, :) isa SubDataFrame
        @test view(sdf, :) == df[2:4, 2:4]
        @test view(sdf, r"") isa SubDataFrame
        @test view(sdf, r"") == df[2:4, 2:4]
        @test view(sdf, Not(1:0)) isa SubDataFrame
        @test view(sdf, Not(1:0)) == df[2:4, 2:4]
        @test parent(view(sdf, :)) == parent(sdf)
        @test parent(view(sdf, r"")) == parent(sdf)
        @test parent(view(sdf, Not(1:0))) == parent(sdf)
    end

    @testset "old setindex! tests" begin
        df = DataFrame(reshape(1:12, 4, :))
        df[1, :] = df[1:1, :]

        df = DataFrame(reshape(1:12, 4, :))

        # Scalar broadcasting assignment of rows
        df[1:2, :] = 1
        df[[true,false,false,true], :] = 3

        # Vector broadcasting assignment of rows
        df[1:2, :] = [2,3]
        df[[true,false,false,true], :] = [2,3]

        # Broadcasting assignment of columns
        df[:, 1] = 1
        df[:x3] = 2

        # assignment of subtables
        df[1, 1:2] = df[2:2, 2:3]
        df[1:2, 1:2] = df[2:3, 2:3]
        df[[true,false,false,true], 2:3] = df[1:2,1:2]

        # scalar broadcasting assignment of subtables
        df[1:2, 1:2] = 3
        df[[true,false,false,true], 2:3] = 3

        # vector broadcasting assignment of subtables
        df[1:2, 1:2] = [3,2]
        df[[true,false,false,true], 2:3] = [2,3]

        # test of 1-row DataFrame assignment
        df = DataFrame([1 2 3])
        df[1, 2:3] = DataFrame([11 12])
        @test df == DataFrame([1 11 12])

        df = DataFrame([1 2 3])
        df[1, [false, true, true]] = DataFrame([11 12])
        @test df == DataFrame([1 11 12])
    end

    @testset "old test/dataframes.jl tests" begin
        df = DataFrame(a = Union{Int, Missing}[2, 3],
                    b = Union{DataFrame, Missing}[DataFrame(c = 1), DataFrame(d = 2)])
        df[1, :b][:e] = 5

        x = DataFrame(a = [1, 2, 3], b = [4, 5, 6])

        #test_group("DataFrame assignment")
        # Insert single column
        x0 = x[Int[], :]
        @test_throws ArgumentError x0[:d] = [1]
        @test_throws ArgumentError x0[:d] = 1:3

        # Insert single value
        x[:d] = 3
        @test x[:d] == [3, 3, 3]
    end

    @testset "test getindex using df[col] and df[cols] syntax" begin
        x = [1]
        y = [1]
        df = DataFrame(x=x, y=y, copycols=false)
        @test df.x === x
        @test df[:y] === y
        @test df[1] === x
        @test df[1:1][1] == x
        @test df[r"x"][1] == x
        @test df[1:1][1] !== x
        @test df[r"x"][1] !== x
        @test df[1:2][:y] == y
        @test df[1:2][:y] !== y
        @test df[r""][:y] == y
        @test df[r""][:y] !== y
        @test df[:][:x] == x
        @test df[:][:x] !== x
        @test df[[:y,:x]][:x] == x
        @test df[[:y,:x]][:x] !== x
    end

    @testset "setindex! special cases" begin
        df = DataFrame(rand(3,2), [:x3, :x3_1])
        @test_throws ArgumentError df[3] = [1, 2]
        @test_throws ArgumentError df[4] = [1, 2, 3]
        df[3] = [1,2,3]
        df[4] = [1,2,3]
        @test names(df) == [:x3, :x3_1, :x3_2, :x4]
        df = DataFrame()
        @test_throws MethodError df[true] = 1
        @test_throws MethodError df[true] = [1,2,3]
        @test_throws MethodError df[1:2, true] = [1,2]
        @test_throws MethodError df[1, true] = 1
        @test_throws ArgumentError df[1, 100] = 1
        @test_throws BoundsError df[1:2, 100] = [1,2]
    end

    @testset "handling of end in indexing" begin
        z = DataFrame(rand(4,5))
        for x in [z, view(z, 1:4, :)]
            y = deepcopy(x)
            @test x[end] == x[5]
            @test x[end:end] == x[5:5]
            @test x[end, :] == x[4, :]
            x[end] = 1:4
            y[5] = 1:4
            @test x == y
            x[4:end] = DataFrame([11:14, 21:24])
            y[4] = [11:14;]
            y[5] = [21:24;]
            @test x == y
        end
    end

    @testset "aliasing in indexing" begin
        # columns should not alias if scalar broadcasted
        df = DataFrame(A=[0], B=[0])
        df[1:end] = 0.0
        df[1, :A] = 1.0
        @test df[1, :B] === 0

        df = DataFrame(A=[0], B=[0])
        df[:, 1:end] = 0.0
        df[1, :A] = 1.0
        @test df[1, :B] === 0

        # columns should not alias if vector assigned
        df = DataFrame(A=[0], B=[0])
        x = [0.0]
        df[1:end] = x
        x[1] = 1.0
        @test df[1, :A] === 0.0
        @test df[1, :B] === 0.0
        df[1, :A] = 1.0
        @test df[1, :B] === 0.0

        df = DataFrame(A=[0], B=[0])
        x = [0.0]
        df[:, 1:end] = x
        x[1] = 1.0
        @test df[1, :A] === 0.0
        @test df[1, :B] === 0.0
        df[1, :A] = 1.0
        @test df[1, :B] === 0.0
    end
end

@testset "eltypes" begin
    @test eltypes(DataFrame(x=[1], y=["a"])) == [Int, String]
end

@testset "melt" begin
    mdf = DataFrame(id=[missing,1,2,3], a=1:4, b=1:4)
    @test unstack(melt(mdf, :id), :id, :variable, :value)[1:3,:] == sort(mdf)[1:3,:]
    @test unstack(melt(mdf, :id), :id, :variable, :value)[:, 2:3] == sort(mdf)[:, 2:3]
    @test unstack(melt(mdf, Not(Not(:id))), :id, :variable, :value)[1:3,:] == sort(mdf)[1:3,:]
    @test unstack(melt(mdf, Not(Not(:id))), :id, :variable, :value)[:, 2:3] == sort(mdf)[:, 2:3]

    Random.seed!(1234)
    x = DataFrame(rand(100, 50))
    x[!, :id] = [1:99; missing]
    x[!, :id2] = string.("a", x[!, :id])
    x[!, :s] = [i % 2 == 0 ? randstring() : missing for i in 1:100]
    allowmissing!(x, :x1)
    x[1, :x1] = missing
    y = melt(x, [:id, :id2])
    @test y ≅ melt(x, r"id")
    @test y ≅ melt(x, Not(Not(r"id")))

    d1 = DataFrame(a = Array{Union{Int, Missing}}(repeat([1:3;], inner = [4])),
                b = Array{Union{Int, Missing}}(repeat([1:4;], inner = [3])),
                c = Array{Union{Float64, Missing}}(randn(12)),
                d = Array{Union{Float64, Missing}}(randn(12)),
                e = Array{Union{String, Missing}}(map(string, 'a':'l')))
    d1s = stack(d1, [:a, :b])
    d1m = melt(d1, [:c, :d, :e])
    @test d1m == melt(d1, r"[cde]")
    @test d1s == d1m
    d1m = melt(d1[:, [1,3,4]], :a)
    @test names(d1m) == [:a, :variable, :value]
    d1m_named = melt(d1[:, [1,3,4]], :a, variable_name=:letter, value_name=:someval)
    @test names(d1m_named) == [:a, :letter, :someval]
    dx = melt(d1, [], [:a])
    @test dx == melt(d1, r"xxx", r"a")
    @test size(dx) == (12, 2)
    @test names(dx) == [:variable, :value]
    dx = melt(d1, :a, [])
    @test dx == stack(d1, r"xxx", r"a")
    @test size(dx) == (0, 3)
    @test names(dx) == [:a, :variable, :value]
    d1m = melt(d1, [:c, :d, :e], view=true)
    @test d1m == melt(d1, r"[cde]", view=true)
    d1m = melt(d1[:, [1,3,4]], :a, view=true)
    @test names(d1m) == [:a, :variable, :value]
    d1m_named = melt(d1, [:c, :d, :e], variable_name=:letter, value_name=:someval, view=true)
    @test d1m_named == melt(d1, r"[cde]", variable_name=:letter, value_name=:someval, view=true)
    @test names(d1m_named) == [:c, :d, :e, :letter, :someval]
    df1 = melt(DataFrame(rand(10,10)))
    df1[!, :id] = 1:100
    @test size(unstack(df1, :variable, :value)) == (100, 11)
    @test_throws ArgumentError unstack(melt(DataFrame(rand(3,2))), :variable, :value)
end

@testset "insertcols!" begin
    df = DataFrame(x = 1:2)
    @test insertcols!(df, 2, y=2:3) == DataFrame(x=1:2, y=2:3)
end

@testset "join" begin
    name = DataFrame(ID = Union{Int, Missing}[1, 2, 3],
                    Name = Union{String, Missing}["John Doe", "Jane Doe", "Joe Blogs"])
    job = DataFrame(ID = Union{Int, Missing}[1, 2, 2, 4],
                    Job = Union{String, Missing}["Lawyer", "Doctor", "Florist", "Farmer"])
    @test_throws ArgumentError join(name, job)
    @test_throws ArgumentError join(name, job, on=:ID, kind=:other)

    df1 = DataFrame(id=[1,2,3], x=[1,2,3])
    df2 = DataFrame(id=[1,2,4], y=[1,2,4])
    df3 = DataFrame(id=[1,3,4], z=[1,3,4])
    @test_throws ArgumentError join(df1, df2, df3, on=:id, kind=:xxx)
end

@testset "eachcol(df, true)" begin
    df = DataFrame(a=1:3, b=4:6, c=7:9)
    @test eachcol(df)[1] === last(eachcol(df, true)[1])
    @test eachcol(df)[1] === last(eachcol(df, true)[1])

    df = DataFrame(rand(3,4), [:a, :b, :c, :d])
    df2 = DataFrame(eachcol(df, true))
    @test df == df2
    df2 = DataFrame!(eachcol(df, true))
    @test df == df2
    @test all(((a,b),) -> a === b, zip(eachcol(df), eachcol(df2)))

    @test Tables.rowtable(df) == Tables.rowtable((;eachcol(df, true)...))
    @test Tables.columntable(df) == Tables.columntable((;eachcol(df, true)...))

    for (a, b, c, d) in zip(Tables.rowtable(df),
                            Tables.namedtupleiterator(eachrow(df)),
                            Tables.namedtupleiterator(eachcol(df)),
                            Tables.namedtupleiterator((;eachcol(df, true)...)))
        @test a isa NamedTuple
        @test a === b === c === d
    end

    @test Tables.getcolumn((;eachcol(df, true)...), 1) == Tables.getcolumn(df, 1)
    @test Tables.getcolumn((;eachcol(df, true)...), :a) == Tables.getcolumn(df, :a)
    @test Tables.columnnames((;eachcol(df, true)...)) == Tuple(Tables.columnnames(df))

    df = DataFrame(A = Vector{Union{Int, Missing}}(1:2), B = Vector{Union{Int, Missing}}(2:3))
    @test size(eachcol(df, true)) == (size(df, 2),)
    @test parent(DataFrame(eachcol(df, true))) == df
    @test names(DataFrame(eachcol(df, true))) == names(df)
    @test IndexStyle(eachcol(df, true)) == IndexLinear()
    @test size(eachcol(df, false)) == (size(df, 2),)
    @test IndexStyle(eachcol(df, false)) == IndexLinear()
    @test length(eachcol(df, true)) == size(df, 2)
    @test length(eachcol(df, false)) == size(df, 2)
    @test eachcol(df, true)[1] == (:A => df[:, 1])
    @test eachcol(df, false)[1] == df[:, 1]
    @test collect(eachcol(df, true)) isa Vector{Pair{Symbol, AbstractVector}}
    @test collect(eachcol(df, true)) == [:A => [1, 2], :B => [2, 3]]
    @test collect(eachcol(df, false)) isa Vector{AbstractVector}
    @test collect(eachcol(df, false)) == [[1, 2], [2, 3]]
    @test eltype(eachcol(df, true)) == Pair{Symbol, AbstractVector}
    @test eltype(eachcol(df, false)) == AbstractVector
    for col in eachcol(df, true)
        @test typeof(col) <: Pair{Symbol, <:AbstractVector}
    end
    for col in eachcol(df, false)
        @test isa(col, AbstractVector)
    end
    @test map(minimum, eachcol(df, false)) == [1, 2]
    @test eltype(map(Vector{Float64}, eachcol(df, false))) == Vector{Float64}

    df = DataFrame([11:16 21:26 31:36 41:46])
    sdf = view(df, [3,1,4], [3,1,4])
    @test eachcol(sdf, true) == eachcol(df[[3,1,4], [3,1,4]], true)
    @test eachcol(sdf, false) == eachcol(df[[3,1,4], [3,1,4]], false)
    @test size(eachcol(sdf, true)) == (3,)
    @test size(eachcol(sdf, false)) == (3,)

    df_base = DataFrame([11:16 21:26 31:36 41:46])
    for df in (df_base, view(df_base, 1:3, 1:3))
        @test df == DataFrame(eachcol(df, true))
    end
end

global_logger(old_logger)

end # module
