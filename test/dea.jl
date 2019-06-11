# Tests for Radial DEA Models
@testset "RadialDEAModel" begin

    ## Test Radial DEA Models with FLS Book data
    X = [5 13; 16 12; 16 26; 17 15; 18 14; 23 6; 25 10; 27 22; 37 14; 42 25; 5 17]
    Y = [12; 14; 25; 26; 8; 9; 27; 30; 31; 26; 12]

    # Input oriented CRS
    deaio = dea(X, Y, orient = :Input, rts = :CRS)

    @test nobs(deaio) == 11
    @test ninputs(deaio) == 2
    @test noutputs(deaio) == 1
    @test efficiency(deaio) ≈ [1.0000000000;
                               0.6222896791;
                               0.8198562444;
                               1.0000000000;
                               0.3103709311;
                               0.5555555556;
                               1.0000000000;
                               0.7576690896;
                               0.8201058201;
                               0.4905660377;
                               1.0000000000]
    @test convert(Matrix, peers(deaio)) ≈
    [1.000000000  0  0 0.0000000000  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 0.4249783174  0  0 0.10928013877  0  0   0   0;
     1.134321653  0  0 0.4380053908  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 1.0000000000  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 0.2573807721  0  0 0.04844814534  0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 0.33333333333  0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 1.00000000000  0  0   0   0;
     0.000000000  0  0 1.0348650979  0  0 0.11457435013  0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 1.14814814815  0  0   0   0;
     0.000000000  0  0 0.4905660377  0  0 0.49056603774  0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 0.00000000000  0  0   0   1.000000000]

    # Otuput oriented CRS
    deaoo = dea(X, Y, orient = :Output, rts = :CRS)

    @test nobs(deaoo) == 11
    @test ninputs(deaoo) == 2
    @test noutputs(deaoo) == 1
    @test efficiency(deaoo) ≈ [1.0000000000;
                               1.606968641;
                               1.219726027;
                               1.0000000000;
                               3.221951220;
                               1.800000000;
                               1.0000000000;
                               1.319837398;
                               1.219354839;
                               2.038461538;
                               1.0000000000]
    @test convert(Matrix, peers(deaoo)) ≈
    [1.000000000  0  0 0.0000000000  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 0.6829268293  0  0 0.1756097561   0  0   0   0;
     1.383561644  0  0 0.5342465753  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 1.0000000000  0  0 0.00000000000  0  0   0   0;
     0.000000000  0  0 0.8292682927  0  0 0.1560975610   0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 0.6000000000   0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 1.00000000000  0  0   0   0;
     0.000000000  0  0 1.3658536585  0  0 0.1512195122   0  0   0   0;
     0.000000000  0  0 0.0000000000  0  0 1.4000000000   0  0   0   0;
     0.000000000  0  0 1.0000000000  0  0 1.0000000000   0  0   0   0;
     1.000000000  0  0 0.0000000000  0  0 0.00000000000  0  0   0   0]

    # Input oriented VRS
    deaiovrs = dea(X, Y, orient = :Input, rts = :VRS)

    @test nobs(deaiovrs) == 11
    @test ninputs(deaiovrs) == 2
    @test noutputs(deaiovrs) == 1
    @test efficiency(deaiovrs) ≈ [1.0000000000;
                                  0.8699861687;
                                  1.0000000000;
                                  1.0000000000;
                                  0.7116402116;
                                  1.0000000000;
                                  1.0000000000;
                                  1.0000000000;
                                  1.0000000000;
                                  0.4931209269;
                                  1.0000000000]
    @test convert(Matrix, peers(deaiovrs)) ≈
    [1.000000000    0  0 0.0000000000  0  0.00000000000 0.00000000000  0  0   0   0;
     0.52558782849  0  0 0.0000000000  0  0.2842323651  0.1901798064   0  0   0   0;
     0.000000000    0  1 0.0000000000  0  0.00000000000 0.00000000000  0  0   0   0;
     0.000000000    0  0 1.0000000000  0  0.00000000000 0.00000000000  0  0   0   0;
     0.56613756614  0  0 0.0000000000  0  0.4338624339  0.00000000000  0  0   0   0;
     0.000000000    0  0 0.0000000000  0  1.00000000000 0.00000000000  0  0   0   0;
     0.000000000    0  0 0.0000000000  0  0.00000000000 1.00000000000  0  0   0   0;
     0.000000000    0  0 0.0000000000  0  0.00000000000 0.00000000000  1  0   0   0;
     0.000000000    0  0 0.0000000000  0  0.00000000000 0.00000000000  0  1   0   0;
     0.03711078928  0  0 0.4433381608  0  0.00000000000 0.5195510500   0  0   0   0;
     0.000000000    0  0 0.0000000000  0  0.00000000000 0.00000000000  0  0   0   1.000000000]

    # Output oriented VRS
    deaoovrs = dea(X, Y, orient = :Output, rts = :VRS)

    @test nobs(deaoovrs) == 11
    @test ninputs(deaoovrs) == 2
    @test noutputs(deaoovrs) == 1
    @test efficiency(deaoovrs) ≈ [1.0000000000;
                                  1.507518797;
                                  1.0000000000;
                                  1.0000000000;
                                  3.203947368;
                                  1.000000000;
                                  1.0000000000;
                                  1.000000000;
                                  1.000000000;
                                  1.192307692;
                                  1.0000000000]
    @test convert(Matrix, peers(deaoovrs)) ≈
    [1.000000000   0  0 0.0000000000  0  0 0.00000000000  0  0   0   0;
     0.38157894737 0  0 0.1710526316  0  0 0.4473684211   0  0   0   0;
     0.000000000   0  1 0.0000000000  0  0 0.00000000000  0  0   0   0;
     0.000000000   0  0 1.0000000000  0  0 0.00000000000  0  0   0   0;
     0.03947368421 0  0 0.7763157895  0  0 0.1842105263   0  0   0   0;
     0.000000000   0  0 0.0000000000  0  1 0.00000000000  0  0   0   0;
     0.000000000   0  0 0.0000000000  0  0 1.00000000000  0  0   0   0;
     0.000000000   0  0 0.0000000000  0  0 0.00000000000  1  0   0   0;
     0.000000000   0  0 0.0000000000  0  0 0.00000000000  0  1   0   0;
     0.000000000   0  0 0.0000000000  0  0 0.00000000000  0  1   0   0;
     1.000000000   0  0 0.0000000000  0  0 0.00000000000  0  0   0   0]

end