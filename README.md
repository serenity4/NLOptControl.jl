# NLOptControl.jl

[![Latest](https://img.shields.io/badge/docs-latest-blue.svg)](http://nloptcontroljl.readthedocs.io/en/latest/)

NOTE: This package is a work in progress!

A current limitation of optimization modeling software, such as [JuMP](https://github.com/JuliaOpt/JuMP.jl) is that it does not allow for ease of adding integral constraint equations. The aim of this package is to provide functionality to:
  * Allow the user to write a system of coupled ODEs that governs the dynamic behavior of the model such as:

  TODO: insert basic equations and assume some form of @ODEconstraint(mdl, xdot = f(x,t), a, b)  

  where, a = t0, b = tf, mdl is the current model, and xdot = f(x,t) is an ODE.

  * provide an implementation of the [hp-pseudospectral method](http://vdol.mae.ufl.edu/JournalPublications/TOMS-GPOPS-II-August-2013.pdf) written in written in the [Julia-language](http://julialang.org/)

  * The ultimate goal is to eventually utilize and support both [Julia DiffEQ](https://github.com/JuliaDiffEq) and [JuMP](https://github.com/JuliaOpt/JuMP.jl)

## Documentation

The full documentation can be found [here](http://nloptcontroljl.readthedocs.io/en/latest/).

## Installation

In Julia, you can install the NLOptControl.jl package by typing:
```julia
julia>Pkg.clone("https://github.com/huckl3b3rry87/NLOptControl.jl")
``

## MathProgBase

NLOptControl uses the [MathProgBase interface](http://mathprogbasejl.readthedocs.org/en/latest/nlp.html)


## Tutorial

TODO: Make an IJulia notebook for this