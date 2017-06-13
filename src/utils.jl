"""
linearStateTolerances!(n)
# the purpose of this function is to taper the tolerances on the constant state constraints
# the idea is that when doing MPC, the final states are well within the bounds so that the next optimization is not initalized at an infeasible point
# if you want a constant bond, set the slope to zero
# default is a positive slope on the lower bound and a negative slope on the upper bound
# this functionality in not needed for states like position, so you do not need to add a linearStateTol for all states

--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 3/23/2017, Last Modified: 3/25/2017 \n
-------------------------------------------------------------------------------------\n
"""
function linearStateTolerances!(n::NLOpt;
                                mXL::Array{Any,1}=falses(n.numStates),
                                mXU::Array{Any,1}=falses(n.numStates))
  n.mXL=mXL;  n.mXU=mXU;
  for st in 1:n.numStates
    # lower state constraint
    if n.mXL[st]!=false
      if !isnan(n.XL[st])
        for j in 1:n.numStatePoints
        n.XL_var[st,j]=n.XL[st] + n.mXL[st]*(j/n.numStatePoints); # lower
        end
      end
    end

    # upper state constraint
    if n.XU[st]!=false
      if !isnan(n.XU[st])
        for j in 1:n.numStatePoints
        n.XU_var[st,j]=n.XU[st] + n.mXU[st]*(j/n.numStatePoints); # upper
        end
      end
    end
  end
  nothing
end

"""
defineTolerances!(n)
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 2/8/2017, Last Modified: 2/8/2017 \n
-------------------------------------------------------------------------------------\n
"""
function defineTolerances!(n::NLOpt;
                          X0_tol::Array{Float64,1}=0.05*ones(Float64,n.numStates,),
                          XF_tol::Array{Float64,1}=0.05*ones(Float64,n.numStates,))
  n.X0_tol=X0_tol; n.XF_tol=XF_tol;
  nothing
end

"""
create_tV!(n)
# define a time vector (n.tV) for use with time varying constraints when (finalTimeDV=>true)
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 3/17/2017, Last Modified: 3/17/2017 \n
--------------------------------------------------------------------------------------\n
"""
function create_tV!(n::NLOpt)

  if n.s.integrationMethod==:ps
    if n.s.finalTimeDV
      # create mesh points, interval size = tf_var/Ni
      tm = @NLexpression(n.mdl, [idx=1:n.Ni+1], (idx-1)*n.tf/n.Ni);
      # go through each mesh interval creating time intervals; [t(i-1),t(i)] --> [-1,1]
      ts = [Array(Any,n.Nck[int]+1,) for int in 1:n.Ni];
      for int in 1:n.Ni
        ts[int][1:end-1]=@NLexpression(n.mdl,[j=1:n.Nck[int]], (tm[int+1]-tm[int])/2*n.τ[int][j] +  (tm[int+1]+tm[int])/2);
        ts[int][end]=@NLexpression(n.mdl, n.tf/n.Ni*int) # append +1 at end of each interval
      end
      tt1 = [idx for tempM in ts for idx = tempM[1:end-1]];
      tmp = [tt1;ts[end][end]];
      n.tV = @NLexpression(n.mdl,[j=1:n.numStatePoints], n.mpc.t0_param + tmp[j]);
    else
      error("finish this")
    end
  else
    error("finish this")

    if n.s.finalTimeDV
      # vector with the design variable in it
      t = Array(Any,n.N+1,1);
      tmp = [0;cumsum(n.dt)];
      n.tV = @NLexpression(n.mdl,[j=1:n.numStatePoints], n.t0 + tmp[j]);
    else

    end
  end
  return nothing
end

"""
# for integrating JuMP variables
Expr=integrate!(n,u;(:mode=>:control))
Expr=integrate!(n,u,idx=1;C=0.5,(:variable=>:control),(:integrand=>:squared))
Expr=integrate!(n,n.r.u[:,1];D=rand(n.numStatePoints),(:variable=>:control),(:integrand=>:squared),(:integrandAlgebra=>:subtract))
#TODO fix D  ::Array{JuMP.NonlinearParameter,1}
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 1/2/2017, Last Modified: 5/29/2017 \n
--------------------------------------------------------------------------------------\n
"""
function integrate!(n::NLOpt,V::Array{JuMP.Variable,1}, args...; C=1.0,D=zeros(n.numStatePoints,),kwargs...)
  kw = Dict(kwargs);
  if !haskey(kw,:integrand); kw_ = Dict(:integrand => :default); integrand = get(kw_,:integrand,0);
  else; integrand = get(kw,:integrand,0);
  end
  if !haskey(kw,:integrandAlgebra); kw_ = Dict(:integrandAlgebra => :default); integrandAlgebra = get(kw_,:integrandAlgebra,0);
  else; integrandAlgebra = get(kw,:integrandAlgebra,0);
  end

  if integrandAlgebra ==:subtract
    if n.s.integrationMethod==:tm
      if integrand == :default      # integrate V
        if n.s.integrationScheme==:bkwEuler
          Expr =  @NLexpression(n.mdl,C*sum((V[j+1]-D[j])*n.tf/(n.N) for j = 1:n.N));  #TODO fix this.. there is an extra dv here for control, but it does not effect solution
        elseif n.integrationScheme==:trapezoidal
          Expr =  @NLexpression(n.mdl,C*sum(0.5*((V[j]-D[j]+V[j+1]-D[j])*n.tf/(n.N) for j = 1:n.N)));
        end
      elseif integrand == :squared # integrate V^2
        if n.s.integrationScheme==:bkwEuler
          Expr =  @NLexpression(n.mdl, C*sum(((V[j+1]-D[j])^2)*n.tf/(n.N) for j = 1:n.N));
        elseif n.integrationScheme==:trapezoidal
          Expr =  @NLexpression(n.mdl, C*sum(0.5*((V[j]-D[j])^2+(V[j+1]-D[j])^2)*n.tf/(n.N) for j = 1:n.N));
        end
      else
        error("\n Check :integrand \n")
      end
    elseif n.s.integrationMethod==:ps
      if !haskey(kw,:mode); kw_ = Dict(:mode => :quadrature); mode = get(kw_,:mode,0);
      else; mode  = get(kw,:mode,0);
      end
      variable = get(kw,:variable,0);
      if variable == :state; Nck_cum=[0;cumsum(n.Nck)];Nck_cum=[0;cumsum(n.Nck)];Nck_cum[end]=Nck_cum[end]+1;
      elseif variable == :control; Nck_cum = [0;cumsum(n.Nck)];
      else; error("\n Set the variable to either (:variable => :state) or (:variable => :control). \n")
      end

      if mode == :quadrature  #TODO recalculate ws based off of time
        if integrand == :default      # integrate V
          @NLexpression(n.mdl, temp[int=1:n.Ni], ((n.tf-n.t0)/2)*sum((n.ωₛ[int])[j]*((V[Nck_cum[int]+1:Nck_cum[int+1]])[j]-D[j]) for j = 1:n.Nck[int]));
          Expr =  @NLexpression(n.mdl, C*sum(temp[int] for int = 1:n.Ni));
        elseif integrand == :squared # integrate V^2
          @NLexpression(mdl, temp[int=1:n.Ni],((n.tf-n.t0)/2)*C*sum((n.ωₛ[int])[j]*((V[Nck_cum[int]+1:Nck_cum[int+1]])[j]-D[j])*((V[Nck_cum[int] + 1:Nck_cum[int+1]])[j]-D[j]) for j = 1:n.Nck[int]));
          Expr =  @NLexpression(n.mdl, sum(temp[int] for int = 1:n.Ni));
        else
          error("\n Check :integrand \n")
        end
      elseif mode == :LGRIM# TODO add in option to allow for integration using IMatrix
          error("\n Not implemented yet!! \n")
      end
    end
  elseif integrandAlgebra==:default
    if n.s.integrationMethod==:tm
      if integrand == :default      # integrate V
        if n.s.integrationScheme==:bkwEuler
          Expr =  @NLexpression(n.mdl,C*sum(V[j+1]*n.tf/(n.N) for j = 1:n.N));  #TODO fix this.. there is an extra dv here for control, but it does not effect solution
        elseif n.s.integrationScheme==:trapezoidal
          Expr =  @NLexpression(n.mdl,C*sum(0.5*(V[j]+V[j+1])*n.tf/(n.N) for j = 1:n.N));
        end
      elseif integrand == :squared # integrate V^2
        if n.s.integrationScheme==:bkwEuler
          Expr =  @NLexpression(n.mdl, C*sum((V[j+1]^2)*n.tf/(n.N) for j = 1:n.N));
        elseif n.s.integrationScheme==:trapezoidal
          Expr =  @NLexpression(n.mdl, C*sum(0.5*(V[j]^2+V[j+1]^2)*n.tf/(n.N) for j = 1:n.N));
        end
      else
        error("\n Check :integrand \n")
      end
    elseif n.s.integrationMethod==:ps
      if !haskey(kw,:mode); kw_ = Dict(:mode => :quadrature); mode = get(kw_,:mode,0);
      else; mode  = get(kw,:mode,0);
      end
      variable = get(kw,:variable,0);
      if variable == :state; Nck_cum=[0;cumsum(n.Nck)];Nck_cum=[0;cumsum(n.Nck)];Nck_cum[end]=Nck_cum[end]+1;
      elseif variable == :control; Nck_cum = [0;cumsum(n.Nck)];
      else; error("\n Set the variable to either (:variable => :state) or (:variable => :control). \n")
      end

      if mode == :quadrature
        if integrand == :default      # integrate V
          @NLexpression(n.mdl, temp[int=1:n.Ni], ((n.tf-n.t0)/2)*sum((n.ωₛ[int])[j]*(V[Nck_cum[int]+1:Nck_cum[int+1]])[j] for j = 1:n.Nck[int]));
          Expr=@NLexpression(n.mdl, C*sum(temp[int] for int = 1:n.Ni));
        elseif integrand == :squared # integrate V^2
          @NLexpression(n.mdl, temp[int=1:n.Ni],((n.tf-n.t0)/2)*sum(n.ωₛ[int][j]*(V[Nck_cum[int]+1:Nck_cum[int+1]])[j]*(V[Nck_cum[int]+1:Nck_cum[int+1]])[j] for j = 1:n.Nck[int]));
          Expr=@NLexpression(n.mdl, C*sum(temp[int] for int = 1:n.Ni));
        else
          error("\n Check :integrand \n")
        end
      elseif mode == :LGRIM# TODO add in option to allow for integration using IMatrix
          error("\n Not implemented yet!! \n")
      end
    end
  end
  return Expr
end

########################################################################################
# constraint data functions
########################################################################################
"""
# funtionality to save constraint data
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 2/7/2017, Last Modified: 3/6/2017 \n
--------------------------------------------------------------------------------------\n
"""
function initConstraint!(n)
  if n.r.constraint==nothing
    n.r.constraint=Constraint()
  end
  nothing
end

function newConstraint!(n,handle,name::Symbol)
  initConstraint!(n)
  n.r.constraint::Constraint=n.r.constraint
  push!(n.r.constraint.handle,handle)
  push!(n.r.constraint.name,name)
  nothing
end


"""
maxDualInf = evalMaxDualInf(n)
# funtionality to evaluate maximum dual infeasibility of problem
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 2/13/2017, Last Modified: 2/13/2017 \n
--------------------------------------------------------------------------------------\n
"""
function evalMaxDualInf(n::NLOpt)
  num=length(n.r.constraint.handle); dual_con_temp=zeros(num);
  for i = 1:length(n.r.constraint.handle)
    if !isempty(n.r.constraint.handle[i])
      if n.r.constraint.name[i]==:dyn_con  # state constraits
        temp1=zeros(n.numStates);
        for st in 1:n.numStates
          if n.r.integrationMethod==:ps
            temp=[getdual(n.r.constraint.handle[i][int][:,st]) for int in 1:n.Ni];
            vals=[idx for tempM in temp for idx=tempM];
            temp1[st]=maximum(vals);
          else
            temp1[st] = maximum(getdual(n.r.constraint.handle[i][:,st]));
          end
        end
        dual_con_temp[i]=maximum(temp1);
      else
        S=JuMP.size(n.r.constraint.handle[i])
        if length(S)==1
          dual_con_temp[i]=maximum(getdual(n.r.constraint.handle[i][:]));
        elseif length(S)==2
          temp1=zeros(S[1]);
          for idx in 1:S[1]
            temp1[idx] = maximum(getdual(n.r.constraint.handle[i][idx,:]));
          end
          dual_con_temp[i]=maximum(temp1);
        end
      end
    end
  end
  return maximum(maximum(maximum(dual_con_temp)))
end

########################################################################################
# state data functions
########################################################################################
"""
# initialize state names
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 2/7/2017, Last Modified: 3/6/2017 \n
--------------------------------------------------------------------------------------\n
"""

function initStateNames(n::NLOpt)
  State([Symbol("x$i") for i in 1:n.numStates],
        [String("x$i") for i in 1:n.numStates],
       );
end

function stateNames!(n::NLOpt,names,descriptions)
  if !n.define
    error("\n call define() before calling controlNames() \n")
  end
  if length(names)!=n.numStates || length(descriptions)!=n.numStates
    error("\n Check sizes of names and descriptions \n")
  end
  n.state::State = State() # reset
  for i in 1:n.numStates
    push!(n.state.name,names[i])
    push!(n.state.description,descriptions[i])
  end
  nothing
end

########################################################################################
# control data functions
########################################################################################
"""
# initialize control names
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 2/7/2017, Last Modified: 3/6/2017 \n
--------------------------------------------------------------------------------------\n
"""
function initControlNames(n::NLOpt)
  Control([Symbol("u$i") for i in 1:n.numControls],
          [String("u$i") for i in 1:n.numControls]);
end

function controlNames!(n::NLOpt,names,descriptions)
  if !n.define
    error("\n call define() before calling controlNames() \n")
  end
  if length(names)!=n.numControls || length(descriptions)!=n.numControls
    error("\n Check sizes of names and descriptions \n")
  end
  n.control::Control = Control() # reset
  for i in 1:n.numControls
    push!(n.control.name,names[i])
    push!(n.control.description,descriptions[i])
  end
  nothing
end

########################################################################################
# data related functions
########################################################################################

"""
description = string(
" *  \n ")

resultsDir!(r;results_name,description=description)
# removes results folder and creates a new one
# TODO consider putting in a warning or some sort of an interaction with user
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 3/26/2017, Last Modified: 5/29/2017 \n
--------------------------------------------------------------------------------------\n
"""
function resultsDir!(n;results_name::String="",description::String="no description given")
 results_dir=string(n.r.main_dir,"/results/",results_name)  # define directories
 n.r.results_dir=results_dir;

 if isdir(n.r.results_dir)
   rm(n.r.results_dir; recursive=true)
   print("\n The old results have all been deleted! \n \n")
 end
 mkdir(n.r.results_dir)# create directory

 description_str = string(
 "In this test: \n
  RESULTS DISCUSSION:  \n
  * " , description )

 cd(n.r.results_dir)
   write("description.txt", description_str)
 cd(n.r.main_dir)
 return nothing
end


"""
------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 3/26/2017, Last Modified: 4/27/2017 \n
--------------------------------------------------------------------------------------\n
"""

function savePlantData!(n)
  dfs=DataFrame();
  temp = [n.r.dfs_plant[jj][:t][1:end-1,:] for jj in 1:length(n.r.dfs_plant)]; # time
  U=[idx for tempM in temp for idx=tempM]; dfs[:t]=U;

  for st in 1:n.numStates # state
    temp = [n.r.dfs_plant[jj][n.state.name[st]][1:end-1,:] for jj in 1:length(n.r.dfs_plant)];
    U=[idx for tempM in temp for idx=tempM];
    dfs[n.state.name[st]]=U;
  end

  for ctr in 1:n.numControls # control
    temp = [n.r.dfs_plant[jj][n.control.name[ctr]][1:end-1,:] for jj in 1:length(n.r.dfs_plant)];
    U=[idx for tempM in temp for idx=tempM];
    dfs[n.control.name[ctr]]=U;
  end
  cd(n.r.results_dir)
    writetable("plant_data.csv",dfs);
  cd(n.r.main_dir)
  return nothing
end


"""
# maximum(x->maximum(x[:A]), dfs) -> consider
# maximum(x->maximum(filter(y->y !== nothing, x[:A])), dfs)
# minimum(x->maximum(filter(y->y !== nothing, x[:t])), dfs)
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 12/8/2016, Last Modified: 3/29/2017 \n
--------------------------------------------------------------------------------------\n
"""
function minDF(dfs,varb)
  k=length(dfs); tmp=1e10*ones(k,1);
  for i in 1:k
    if dfs[i]!=nothing
      tmp[i]=minimum(dfs[i][varb])
    end
  end
  minimum(tmp)  # find the minimum
end

"""
--------------------------------------------------------------------------------------\n
Author: Huckleberry Febbo, Graduate Student, University of Michigan
Date Create: 12/8/2016, Last Modified: 3/29/2017 \n
--------------------------------------------------------------------------------------\n
"""
function maxDF(dfs,varb)
  k=length(dfs); tmp=1e-10*ones(k,1);
  for i in 1:k
    if dfs[i]!=nothing
      tmp[i]=maximum(dfs[i][varb])
    end
  end
  maximum(tmp)  # find the minimum
end


# credit JuMP.jl
function try_import(name::Symbol)
 try
      @eval import $name
      return true
  catch e
      return false
  end
end
